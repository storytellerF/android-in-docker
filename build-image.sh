#!/bin/bash
set -e

IMAGE_NAME="android-in-docker"
IMAGE_TAG="latest"

echo "Building the Docker image..."

# Get KVM_GID from WSL or local system
if command -v wsl.exe &> /dev/null; then
    # Running on Windows with WSL
    KVM_GID=$(wsl.exe getent group kvm | cut -d: -f3)
else
    # Running on Linux
    KVM_GID=$(getent group kvm | cut -d: -f3)
fi

docker build --build-arg OPENJDK_VERSION=21 --build-arg KVM_GID="${KVM_GID}" -t "${IMAGE_NAME}:${IMAGE_TAG}" -f Dockerfile .
echo "Docker image build process finished."
echo "Image created: ${IMAGE_NAME}:${IMAGE_TAG}"
