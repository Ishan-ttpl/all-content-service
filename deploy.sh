#!/bin/bash
set -e
TARGET_DIR="$1"
REF="$2"  # Branch for deploy, tag for rollback
ACTION="$3"  # deploy or rollback

cd "$TARGET_DIR" || { echo "Error: Directory $TARGET_DIR not found."; exit 1; }
echo "Fetching all latest changes..."
git fetch --all
if [ "$ACTION" = "deploy" ]; then
    echo "Checking out branch: $REF..."
    git checkout "$REF" || { echo "Error: Failed to checkout branch $REF."; exit 1; }
    echo "Pulling latest changes for $REF..."
    git pull origin "$REF" || { echo "Error: Failed to pull from origin $REF."; exit 1; }
elif [ "$ACTION" = "rollback" ]; then
    echo "Checking out tag: $REF..."
    git checkout "tags/$REF" || { echo "Error: Failed to checkout tag $REF."; exit 1; }
else
    echo "Error: Invalid action $ACTION. Expected 'deploy' or 'rollback'."
    exit 1
fi
echo "Stopping existing Docker containers..."
docker-compose down || echo "No running containers to stop."
echo "Building and starting new Docker containers..."
docker-compose up -d --build || { echo "Error: Docker compose failed."; exit 1; }
echo "Cleaning dangling Docker images..."
docker images --no-trunc -aqf "dangling=true" | xargs docker rmi || echo "No dangling images."
echo "Removing temporary .env file..."
rm -f .env || echo "No .env file to remove."
echo "$ACTION complete for $REF."
