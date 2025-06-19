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

# Check for nested all-content-service/ directory
if [ -d "all-content-service/.git" ]; then
  echo "Warning: Found nested all-content-service/.git, moving contents..."
  mv all-content-service/* all-content-service/.git . || { echo "Failed to move nested directory contents"; exit 1; }
  rm -rf all-content-service/ || true
fi

# Ensure docker directory exists
mkdir -p "$TARGET_DIR/docker" || { echo "Failed to create $TARGET_DIR/docker"; exit 1; }

# Verify .git directory
if [ ! -d ".git" ]; then
  echo "Error: .git directory not found in $TARGET_DIR, cloning repository..."
  cd ..
  rm -rf "$(basename "$TARGET_DIR")" || true
  git clone git@github.com:your-org/all-content-service.git "$(basename "$TARGET_DIR")" || { echo "Failed to clone repository"; exit 1; }
  cd "$TARGET_DIR" || { echo "Failed to cd back to $TARGET_DIR"; exit 1; }
fi

echo "Cleaning up old Docker environment..."
cd "$TARGET_DIR/docker" || { echo "Failed to cd to $TARGET_DIR/docker"; exit 1; }
docker-compose down --remove-orphans || true
docker rm -f content-service || true
docker ps -a
docker images

echo "Checking docker-compose.yml..."
if [ ! -f "$TARGET_DIR/docker-compose.yml" ]; then
  echo "Error: docker-compose.yml not found in $TARGET_DIR"
  exit 1
fi
# Copy docker-compose.yml to docker/ directory
cp "$TARGET_DIR/docker-compose.yml" "$TARGET_DIR/docker/docker-compose.yml" || { echo "Failed to copy docker-compose.yml"; exit 1; }
cat docker-compose.yml

echo "Cleaning up Git working directory..."
cd "$TARGET_DIR" || { echo "Failed to cd to $TARGET_DIR"; exit 1; }
git config --global --add safe.directory "$TARGET_DIR" || { echo "Failed to add safe.directory"; exit 1; }
git stash --include-untracked || true
git reset --hard || true
git clean -fd || true
git status

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
  git log -n 1
elif [ "$ACTION" = "rollback" ]; then
  echo "Rolling back to tag $BRANCH_OR_TAG..."
  git fetch --all --tags || { echo "Failed to fetch tags"; exit 1; }
  git checkout "tags/$BRANCH_OR_TAG" || { echo "Failed to checkout tag $BRANCH_OR_TAG"; exit 1; }
  git reset --hard "tags/$BRANCH_OR_TAG" || { echo "Failed to reset to tags/$BRANCH_OR_TAG"; exit 1; }
  git clean -fd || { echo "Failed to clean"; exit 1; }
  git log -n 1
else
  echo "Error: Invalid action $ACTION"
  exit 1
fi

echo "Building and starting services..."
cd "$TARGET_DIR/docker" || { echo "Failed to cd to $TARGET_DIR/docker"; exit 1; }
docker-compose config || { echo "Error: Invalid docker-compose.yml"; exit 1; }
docker-compose pull || { echo "Error: Failed to pull images"; exit 1; }
docker-compose up -d --build || { echo "Error: Failed to start services"; exit 1; }
docker ps -a
docker logs content-service || echo "No logs available"

echo "Deployment complete."
