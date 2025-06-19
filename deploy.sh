#!/bin/bash
set -e

# Configuration
REPO_URL="https://github.com/Sunbird-ALL/all-content-service.git"
TARGET_DIR="$1"
BRANCH_OR_TAG="$2"
ACTION="$3"
SERVICE_NAME="content-service"
DOCKER_COMPOSE_FILE="docker-compose.yml"
IMAGE_NAME="all-content-service"
NETWORK_NAME="all-learner-ai-services-ai-network"

# Validate inputs
if [ -z "$TARGET_DIR" ] || [ -z "$BRANCH_OR_TAG" ] || [ -z "$ACTION" ]; then
  echo "Usage: $0 <target_dir> <branch_or_tag> <deploy|rollback>"
  exit 1
fi

echo "Starting $ACTION process for $SERVICE_NAME"
echo "Target directory: $TARGET_DIR"
echo "Using branch/tag: $BRANCH_OR_TAG"

# Ensure target directory exists
mkdir -p "$TARGET_DIR" || { echo "Failed to create $TARGET_DIR"; exit 1; }
cd "$TARGET_DIR" || { echo "Failed to cd to $TARGET_DIR"; exit 1; }

# Repository setup
if [ ! -d ".git" ]; then
  echo "Cloning repository..."
  git clone --branch "$BRANCH_OR_TAG" "$REPO_URL" . || { 
    echo "Failed to clone repository";
    echo "Trying fallback to clone then checkout...";
    git clone "$REPO_URL" . && git checkout "$BRANCH_OR_TAG" || exit 1;
  }
else
  echo "Resetting repository..."
  git fetch --all || { echo "Failed to fetch updates"; exit 1; }
  git clean -fd || true
  git reset --hard || true
  
  if [ "$ACTION" = "deploy" ]; then
    echo "Checking out branch: $BRANCH_OR_TAG"
    git checkout "$BRANCH_OR_TAG" || { echo "Failed to checkout branch"; exit 1; }
    git pull origin "$BRANCH_OR_TAG" || { echo "Failed to pull updates"; exit 1; }
  elif [ "$ACTION" = "rollback" ]; then
    echo "Checking out tag: $BRANCH_OR_TAG"
    git checkout "tags/$BRANCH_OR_TAG" || { echo "Failed to checkout tag"; exit 1; }
  fi
fi

# Verify compose file exists
if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
  echo "Error: $DOCKER_COMPOSE_FILE not found in $BRANCH_OR_TAG"
  ls -la
  exit 1
fi

# Docker operations
echo "Stopping existing containers..."
docker-compose -f "$DOCKER_COMPOSE_FILE" down --remove-orphans || true
docker rm -f "$SERVICE_NAME" || true

# Image handling
if [ "$ACTION" = "deploy" ]; then
  echo "Building new image from branch..."
  docker build -t "$IMAGE_NAME:$BRANCH_OR_TAG" . || { echo "Build failed"; exit 1; }
elif [ "$ACTION" = "rollback" ]; then
  if ! docker image inspect "$IMAGE_NAME:$BRANCH_OR_TAG" >/dev/null 2>&1; then
    echo "Image not found, building from tag..."
    docker build -t "$IMAGE_NAME:$BRANCH_OR_TAG" . || { echo "Build failed"; exit 1; }
  fi
fi

echo "Tagging image as latest..."
docker tag "$IMAGE_NAME:$BRANCH_OR_TAG" "$IMAGE_NAME:latest" || { echo "Tagging failed"; exit 1; }

# Network setup
if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
  echo "Creating network $NETWORK_NAME..."
  docker network create "$NETWORK_NAME" || { echo "Network creation failed"; exit 1; }
fi

# Start service
echo "Starting service..."
docker-compose -f "$DOCKER_COMPOSE_FILE" up -d || { echo "Start failed"; exit 1; }

# Verification
echo "Verifying deployment..."
sleep 5
if ! docker ps --filter "name=$SERVICE_NAME" --format "{{.Status}}" | grep -q "Up"; then
  echo "Service failed to start"
  docker logs "$SERVICE_NAME" || true
  exit 1
fi

# Summary
echo -e "\nDeployment successful!"
echo "---------------------------------"
echo "Service:     $SERVICE_NAME"
echo "Image:       $IMAGE_NAME:latest"
echo "Source:      $BRANCH_OR_TAG"
echo "Network:     $NETWORK_NAME"
echo "Port:        3008"
echo "---------------------------------"
echo "Container status:"
docker ps --filter "name=$SERVICE_NAME" --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}"
echo -e "\nService logs (last 20 lines):"
docker logs "$SERVICE_NAME" --tail 20 || echo "No logs available"

exit 0
