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

if [[ "$ACTION" == "deploy" ]]; then
  echo "Deploying branch $BRANCH_OR_TAG..."
  git fetch --all
  git checkout "$BRANCH_OR_TAG" || { echo "Failed to checkout $BRANCH_OR_TAG, falling back to lais-v2.0"; git checkout lais-v2.0; }
  git reset --hard origin/"$BRANCH_OR_TAG"
  git clean -fd
  git pull origin "$BRANCH_OR_TAG" || { echo "Failed to pull $BRANCH_OR_TAG, pulling lais-v2.0"; git pull origin lais-v2.0; }
elif [[ "$ACTION" == "rollback" ]]; then
  echo "Rolling back to tag $BRANCH_OR_TAG..."
  git fetch --all --tags
  git checkout "tags/$BRANCH_OR_TAG" || { echo "Failed to checkout tag $BRANCH_OR_TAG"; exit 1; }
  git reset --hard "tags/$BRANCH_OR_TAG"
  git clean -fd
else
  echo "Invalid action: $ACTION"
  exit 1
fi

echo "Building and starting services..."
docker-compose pull || { echo "Failed to pull images"; exit 1; }
docker-compose up -d --build || { echo "Failed to start services"; exit 1; }

echo "Deployment completed."
