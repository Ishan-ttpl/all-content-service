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
NETWORK_NAME="all-learner-ai-services_ai-network"  # Corrected network name

# Validate inputs
[ -z "$TARGET_DIR" ] && { echo "ERROR: Target directory missing"; exit 1; }
[ -z "$BRANCH_OR_TAG" ] && { echo "ERROR: Branch/Tag missing"; exit 1; }
[ -z "$ACTION" ] && { echo "ERROR: Action (deploy/rollback) missing"; exit 1; }

echo "=== Starting $ACTION process ==="
echo "Target: $TARGET_DIR"
echo "Version: $BRANCH_OR_TAG"

# Setup directory
mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR" || { echo "ERROR: Cannot access $TARGET_DIR"; exit 1; }

# Clone or update repository
if [ ! -d ".git" ]; then
  echo "Cloning fresh repository..."
  git clone --branch "$BRANCH_OR_TAG" "$REPO_URL" . || {
    echo "WARNING: Branch checkout failed, cloning main then checking out"
    git clone "$REPO_URL" . && git checkout "$BRANCH_OR_TAG"
  } || { echo "ERROR: Git operations failed"; exit 1; }
else
  echo "Updating existing repository..."
  git fetch --all || { echo "ERROR: Git fetch failed"; exit 1; }
  git clean -fd
  git reset --hard
  
  if [ "$ACTION" = "deploy" ]; then
    git checkout "$BRANCH_OR_TAG" && git pull origin "$BRANCH_OR_TAG" || {
      echo "ERROR: Cannot checkout branch $BRANCH_OR_TAG"; exit 1
    }
  else
    git checkout "tags/$BRANCH_OR_TAG" || {
      echo "ERROR: Cannot checkout tag $BRANCH_OR_TAG"; exit 1
    }
  fi
fi

# Verify compose file
[ ! -f "$DOCKER_COMPOSE_FILE" ] && {
  echo "ERROR: $DOCKER_COMPOSE_FILE not found in $PWD"
  ls -la
  exit 1
}

# Docker cleanup - more thorough approach
echo "Stopping and removing existing containers..."
docker-compose -f "$DOCKER_COMPOSE_FILE" down --remove-orphans --rmi local || true
docker rm -f "$SERVICE_NAME" || true
docker rmi -f "$IMAGE_NAME:latest" "$IMAGE_NAME:$BRANCH_OR_TAG" || true

# Build image
echo "Building Docker image..."
docker build -t "$IMAGE_NAME:$BRANCH_OR_TAG" . || {
  echo "ERROR: Docker build failed"; exit 1
}

docker tag "$IMAGE_NAME:$BRANCH_OR_TAG" "$IMAGE_NAME:latest" || {
  echo "ERROR: Docker tag failed"; exit 1
}

# Ensure network exists - using correct name
if ! docker network inspect "$NETWORK_NAME" &>/dev/null; then
  echo "Creating Docker network..."
  docker network create "$NETWORK_NAME" || {
    echo "ERROR: Network creation failed"; exit 1
  }
fi

# Start service
echo "Starting service..."
docker-compose -f "$DOCKER_COMPOSE_FILE" up -d --force-recreate || {
  echo "ERROR: Service start failed"; exit 1
}

# Verification
echo "Waiting for service to start..."
sleep 10
if ! docker ps --filter "name=$SERVICE_NAME" --format "{{.Status}}" | grep -q "Up"; then
  echo "ERROR: Service not running"
  echo "=== Service logs ==="
  docker logs "$SERVICE_NAME" --tail 50 || true
  exit 1
fi

echo "=== Deployment Successful ==="
echo "Service: $SERVICE_NAME"
echo "Image: $IMAGE_NAME:latest ($BRANCH_OR_TAG)"
echo "Network: $NETWORK_NAME"
echo "Port: 3008"
echo "=== Running Containers ==="
docker ps --filter "name=$SERVICE_NAME" --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}"

exit 0
