#!/bin/bash
set -e

IMAGE_NAME="android-in-docker"
IMAGE_TAG="latest"

echo "Building the Docker image..."
docker build --build-arg OPENJDK_VERSION=21 -t "${IMAGE_NAME}:${IMAGE_TAG}" .
echo "Docker image build process finished."
echo "Image created: ${IMAGE_NAME}:${IMAGE_TAG}"
