#!/bin/bash

set -e

TARGET_DIR="$1"
BRANCH_OR_TAG="$2"
ACTION="$3"

if [[ -z "$TARGET_DIR" || -z "$BRANCH_OR_TAG" || -z "$ACTION" ]]; then
  echo "Usage: $0 <target_dir> <branch_or_tag> <deploy|rollback>"
  exit 1
fi

cd "$TARGET_DIR" || { echo "Failed to cd to $TARGET_DIR"; exit 1; }

echo "Cleaning up old Docker environment..."
docker-compose down --remove-orphans || true
docker rm -f content-service || true
docker network rm ai-network || true
docker network create all-learner-ai-services-ai-network || true

echo "Checking docker-compose.yml..."
cat docker-compose.yml

echo "Cleaning up Git working directory..."
git stash --include-untracked || true
git reset --hard || true
git clean -fd || true

if [[ "$ACTION" == "deploy" ]]; then
  echo "Deploying branch $BRANCH_OR_TAG..."
  git fetch --all
  if ! git checkout "$BRANCH_OR_TAG" 2>/dev/null; then
    echo "Branch $BRANCH_OR_TAG does not exist, checking out main..."
    git checkout main || { echo "Failed to checkout main"; exit 1; }
    BRANCH_OR_TAG="main"
  fi
  git reset --hard "origin/$BRANCH_OR_TAG" || { echo "Failed to reset to origin/$BRANCH_OR_TAG"; exit 1; }
  git clean -fd
  git pull origin "$BRANCH_OR_TAG" || { echo "Failed to pull from origin $BRANCH_OR_TAG"; exit 1; }
elif [[ "$ACTION" == "rollback" ]]; then
  echo "Rolling back to tag $BRANCH_OR_TAG..."
  git fetch --all --tags
  git checkout "tags/$BRANCH_OR_TAG" || { echo "Failed to checkout tag $BRANCH_OR_TAG"; exit 1; }
  git reset --hard "tags/$BRANCH_OR_TAG"
  git clean -fd
else
