#!/bin/bash
set -e

# Only essential configuration
TARGET_DIR="$1"
BRANCH_OR_TAG="$2"
ACTION="$3"
REPO_URL="https://github.com/Sunbird-ALL/all-content-service.git"

# Validate inputs
[ -z "$TARGET_DIR" ] && { echo "ERROR: Target directory required"; exit 1; }
[ -z "$BRANCH_OR_TAG" ] && { echo "ERROR: Branch/Tag required"; exit 1; }
[ -z "$ACTION" ] && { echo "ERROR: Action (deploy/rollback) required"; exit 1; }

echo "=== Starting $ACTION process ==="
echo "Target: $TARGET_DIR"
echo "Version: $BRANCH_OR_TAG"

# Setup directory
mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR" || { echo "ERROR: Cannot access $TARGET_DIR"; exit 1; }

# Repository operations
if [ ! -d ".git" ]; then
  echo "Cloning repository..."
  git clone --branch "$BRANCH_OR_TAG" "$REPO_URL" . || {
    echo "Falling back to clone + checkout..."
    git clone "$REPO_URL" . && git checkout "$BRANCH_OR_TAG"
  } || { echo "ERROR: Git operations failed"; exit 1; }
else
  echo "Updating repository..."
  git fetch --all || { echo "ERROR: Git fetch failed"; exit 1; }
  git clean -fd
  git reset --hard
  git checkout "$BRANCH_OR_TAG" && git pull origin "$BRANCH_OR_TAG" || {
    echo "ERROR: Cannot checkout $BRANCH_OR_TAG"; exit 1
  }
fi

# Verify compose file exists
[ ! -f "docker-compose.yml" ] && { echo "ERROR: docker-compose.yml not found"; exit 1; }

# Get dynamic values from compose file
SERVICE_NAME=$(docker-compose config --services | head -1)
IMAGE_NAME=$(docker-compose config | awk '/image:/{print $2}' | head -1 | cut -d: -f1)
NETWORK_NAME=$(docker-compose config | awk '/networks:/{getline; print $1}' | head -1)

echo "Detected configuration:"
echo "Service: $SERVICE_NAME"
echo "Image: $IMAGE_NAME"
echo "Network: $NETWORK_NAME"

# Docker operations
echo "Stopping existing containers..."
docker-compose down --remove-orphans || true

echo "Building and starting services..."
docker-compose up -d --build || {
  echo "ERROR: Deployment failed"; exit 1
}

# Verification
echo "Waiting for services to start..."
sleep 15
if ! docker ps --filter "name=$SERVICE_NAME" --format "{{.Status}}" | grep -q "Up"; then
  echo "ERROR: Service not running"
  docker logs "$SERVICE_NAME" --tail 50 || true
  exit 1
fi

echo "=== Deployment Successful ==="
docker ps --filter "name=$SERVICE_NAME" --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}"
exit 0
