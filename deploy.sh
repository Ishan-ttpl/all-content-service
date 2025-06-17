#!/bin/bash

set -e

TARGET_DIR="$1"
BRANCH_OR_TAG="$2"
ACTION="$3"

if [[ -z "$TARGET_DIR" || -z "$BRANCH_OR_TAG" || -z "$ACTION" ]]; then
  echo "Usage: $0 <target_dir> <branch_or_tag> <deploy|rollback>"
  exit 1
fi

echo "Deploying to $TARGET_DIR with $BRANCH_OR_TAG for action $ACTION"

# Ensure target directory exists and is a Git repo
cd "$TARGET_DIR" || { echo "Failed to cd to $TARGET_DIR"; exit 1; }

if [[ ! -d .git ]]; then
  echo "Error: $TARGET_DIR is not a Git repository"
  exit 1
fi

# Ensure docker-compose.yml exists
if [[ ! -f docker-compose.yml ]]; then
  echo "Error: docker-compose.yml not found in $TARGET_DIR"
  exit 1
fi

echo "Cleaning up old Docker environment..."
docker-compose down --remove-orphans || true
docker rm -f content-service || true
docker network rm ai-network || true
docker network create ai-network || true

echo "Cleaning up Git working directory..."
git stash --include-untracked || true
git reset --hard || true
git clean -fd || true

if [[ "$ACTION" == "deploy" ]]; then
  echo "Deploying branch $BRANCH_OR_TAG..."
  git fetch --all || { echo "Failed to fetch from remote"; exit 1; }

  # Check if branch exists
  if git show-ref --verify --quiet "refs/remotes/origin/$BRANCH_OR_TAG"; then
    git checkout "$BRANCH_OR_TAG" || { echo "Failed to checkout $BRANCH_OR_TAG"; exit 1; }
    git reset --hard "origin/$BRANCH_OR_TAG" || { echo "Failed to reset to origin/$BRANCH_OR_TAG"; exit 1; }
    git clean -fd || { echo "Failed to clean"; exit 1; }
    git pull origin "$BRANCH_OR_TAG" || { echo "Failed to pull from origin $BRANCH_OR_TAG"; exit 1; }
  else
    echo "Error: Branch $BRANCH_OR_TAG does not exist"
    exit 1
  fi

elif [[ "$ACTION" == "rollback" ]]; then
  echo "Rolling back to tag $BRANCH_OR_TAG..."
  git fetch --all --tags || { echo "Failed to fetch tags"; exit 1; }

  if git rev-parse "$BRANCH_OR_TAG" >/dev/null 2>&1; then
    git checkout "$BRANCH_OR_TAG" || { echo "Failed to checkout tag $BRANCH_OR_TAG"; exit 1; }
    git clean -fd || { echo "Failed to clean"; exit 1; }
  else
    echo "Error: Tag $BRANCH_OR_TAG does not exist"
    exit 1
  fi
else
  echo "Invalid action: $ACTION"
  exit 1
fi

echo "Building and starting services..."
docker-compose pull || { echo "Failed to pull images"; exit 1; }
docker-compose up -d --build || { echo "Failed to start services"; exit 1; }

echo "Deployment completed."
