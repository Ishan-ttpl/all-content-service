#!/bin/bash

set -e

# Fix line endings
sed -i 's/\r$//' "$0"

TARGET_DIR="$1"
BRANCH_OR_TAG="$2"
ACTION="$3"

if [ -z "$TARGET_DIR" ] || [ -z "$BRANCH_OR_TAG" ] || [ -z "$ACTION" ]; then
  echo "Usage: $0 <target_dir> <branch_or_tag> <deploy|rollback>"
  exit 1
fi

echo "Deploying to $TARGET_DIR with $BRANCH_OR_TAG for action $ACTION"

cd "$TARGET_DIR" || { echo "Failed to cd to $TARGET_DIR"; exit 1; }

echo "Cleaning up old Docker environment..."
# docker-compose down will manage networks defined in docker-compose.yml
# No need to manually remove or create networks if docker-compose is handling them.
docker-compose down --remove-orphans || true
docker rm -f content-service || true # Keep this if you explicitly name the container and want to ensure it's removed

# --- REMOVED THE FOLLOWING LINES ---
# docker network rm ai-network || true
# docker network create all-learner-ai-services-ai-network || true
# --- END REMOVED LINES ---

echo "Checking docker-compose.yml..."
cat docker-compose.yml

echo "Cleaning up Git working directory..."
git stash --include-untracked || true
git reset --hard || true
git clean -fd || true

if [ "$ACTION" = "deploy" ]; then
  echo "Deploying branch $BRANCH_OR_TAG..."
  git fetch --all || { echo "Failed to fetch"; exit 1; }
  if ! git checkout "$BRANCH_OR_TAG" 2>/dev/null; then
    echo "Branch $BRANCH_OR_TAG does not exist, checking out main..."
    git checkout main || { echo "Failed to checkout main"; exit 1; }
    BRANCH_OR_TAG="main"
  fi
  git reset --hard "origin/$BRANCH_OR_TAG" || { echo "Failed to reset to origin/$BRANCH_OR_TAG"; exit 1; }
  git clean -fd || { echo "Failed to clean"; exit 1; }
  git pull origin "$BRANCH_OR_TAG" || { echo "Failed to pull from origin $BRANCH_OR_TAG"; exit 1; }
elif [ "$ACTION" = "rollback" ]; then
  echo "Rolling back to tag $BRANCH_OR_TAG..."
  git fetch --all --tags || { echo "Failed to fetch tags"; exit 1; }
  git checkout "tags/$BRANCH_OR_TAG" || { echo "Failed to checkout tag $BRANCH_OR_TAG"; exit 1; }
  git reset --hard "tags/$BRANCH_OR_TAG" || { echo "Failed to reset to tags/$BRANCH_OR_TAG"; exit 1; }
  git clean -fd || { echo "Failed to clean"; exit 1; }
else
  echo "Error: Invalid action $ACTION"
  exit 1
fi

echo "Building and starting services..."
docker-compose pull || { echo "Error: Failed to pull images"; exit 1; }
docker-compose up -d --build || { echo "Error: Failed to start services"; exit 1; }

echo "Deployment complete."
