#!/bin/bash
set -e

IMAGE_NAME="android-in-docker"
IMAGE_TAG="latest"
ENV_FILE=".env"
DEFAULT_JDK_VERSION="21"
DEFAULT_VNC_PASSWORD="password"
DEFAULT_SYS_IMG_PKG="system-images;android-36;google_apis;x86_64"

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -j, --jdk-version <version>  Specify the OpenJDK version (default: $DEFAULT_JDK_VERSION)"
    echo "  -p, --password <password>    Specify the VNC password (default: $DEFAULT_VNC_PASSWORD)"
    echo "  -s, --system-image <package> Specify the System Image Package (default: $DEFAULT_SYS_IMG_PKG)"
    echo "  -c, --create-env             Create or overwrite the .env file with the specified or default values"
    echo "  -h, --help                   Display this help message"
    exit 1
}

# Parse arguments
CREATE_ENV=false
JDK_VERSION=""
VNC_PASSWORD=""
SYS_IMG_PKG=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -j|--jdk-version)
            JDK_VERSION="$2"
            shift
            ;;
        -p|--password)
            VNC_PASSWORD="$2"
            shift
            ;;
        -s|--system-image)
            SYS_IMG_PKG="$2"
            shift
            ;;
        -c|--create-env)
            CREATE_ENV=true
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown parameter passed: $1"
            usage
            ;;
    esac
    shift
done

# If creating env, handle interactive mode if values not provided
if [ "$CREATE_ENV" = true ]; then
    if [ -z "$JDK_VERSION" ]; then
        read -p "Enter OpenJDK version (default: $DEFAULT_JDK_VERSION): " INPUT_VERSION
        JDK_VERSION="${INPUT_VERSION:-$DEFAULT_JDK_VERSION}"
    fi
    
    if [ -z "$VNC_PASSWORD" ]; then
        read -p "Enter VNC password (default: $DEFAULT_VNC_PASSWORD, enter 'r' for random): " INPUT_PASSWORD
        if [ "$INPUT_PASSWORD" = "r" ]; then
            # Generate a random password (16 characters, alphanumeric)
            VNC_PASSWORD=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 16)
            echo "Generated random VNC password: $VNC_PASSWORD"
        else
            VNC_PASSWORD="${INPUT_PASSWORD:-$DEFAULT_VNC_PASSWORD}"
        fi
    fi

    if [ -z "$SYS_IMG_PKG" ]; then
        read -p "Enter System Image Package (default: $DEFAULT_SYS_IMG_PKG): " INPUT_SysImg
        SYS_IMG_PKG="${INPUT_SysImg:-$DEFAULT_SYS_IMG_PKG}"
    fi

    # Ensure VNC_PASSWORD is set for non-interactive case where -p was not provided
    if [ -z "$VNC_PASSWORD" ]; then
         VNC_PASSWORD="$DEFAULT_VNC_PASSWORD"
    fi
    
    echo "Updating $ENV_FILE with OPENJDK_VERSION=$JDK_VERSION, VNC_PASSWD=$VNC_PASSWORD, and SYS_IMG_PKG=$SYS_IMG_PKG"
    
    if [ -f "$ENV_FILE" ]; then
        # Update OPENJDK_VERSION
        if grep -q "OPENJDK_VERSION" "$ENV_FILE"; then
            sed -i "s/^OPENJDK_VERSION=.*/OPENJDK_VERSION=$JDK_VERSION/" "$ENV_FILE"
        else
            # Ensure newline before appending
            [ -n "$(tail -c1 "$ENV_FILE")" ] && echo >> "$ENV_FILE"
            echo "OPENJDK_VERSION=$JDK_VERSION" >> "$ENV_FILE"
        fi

        # Update VNC_PASSWD
        if grep -q "VNC_PASSWD" "$ENV_FILE"; then
            # Escape valid delimiter characters in password if necessary, but simple alphanumeric is assumed for VNC
            # For robustness, we'll try to use a different delimiter or escape slashes? 
            # VNC passwords are usually simple. Let's assume standard characters for now.
            sed -i "s/^VNC_PASSWD=.*/VNC_PASSWD=$VNC_PASSWORD/" "$ENV_FILE"
        else
            # Ensure newline before appending
            [ -n "$(tail -c1 "$ENV_FILE")" ] && echo >> "$ENV_FILE"
            echo "VNC_PASSWD=$VNC_PASSWORD" >> "$ENV_FILE"
        fi

        # Update SYS_IMG_PKG
        if grep -q "SYS_IMG_PKG" "$ENV_FILE"; then
            sed -i "s/^SYS_IMG_PKG=.*/SYS_IMG_PKG=\"$SYS_IMG_PKG\"/" "$ENV_FILE"
        else
            # Ensure newline before appending
            [ -n "$(tail -c1 "$ENV_FILE")" ] && echo >> "$ENV_FILE"
            echo "SYS_IMG_PKG=\"$SYS_IMG_PKG\"" >> "$ENV_FILE"
        fi
    else
        echo "VNC_PASSWD=$VNC_PASSWORD" > "$ENV_FILE"
        echo "OPENJDK_VERSION=$JDK_VERSION" >> "$ENV_FILE"
        echo "SYS_IMG_PKG=\"$SYS_IMG_PKG\"" >> "$ENV_FILE"
    fi
    
    echo ".env file updated."
fi

# Determine JDK Version to use for build
# Priority: 1. Command line arg (implied if CREATE_ENV was used with a specific version or interactive input became the JDK_VERSION)
# Wait, if I do -c and enter 17, JDK_VERSION becomes 17. 
# If I do -j 17, JDK_VERSION becomes 17.
# Use JDK_VERSION if set.
if [ -n "$JDK_VERSION" ]; then
    BUILD_JDK_VERSION="$JDK_VERSION"
elif [ -f "$ENV_FILE" ]; then
    # Read from .env if it exists and we didn't specify a version arg
    # Note: We rely on the fact that if -c was passed, JDK_VERSION is definitely set above.
    # So we are here only if -c was NOT passed AND -j was NOT passed.
    file_version=$(grep "^OPENJDK_VERSION=" "$ENV_FILE" | cut -d'=' -f2)
    if [ -n "$file_version" ]; then
        BUILD_JDK_VERSION="$file_version"
        echo "Read JDK version from $ENV_FILE: $BUILD_JDK_VERSION"
    else
        BUILD_JDK_VERSION="$DEFAULT_JDK_VERSION"
        echo "OPENJDK_VERSION not found in $ENV_FILE. Using default: $BUILD_JDK_VERSION"
    fi
else
    BUILD_JDK_VERSION="$DEFAULT_JDK_VERSION"
    echo "No .env file and no argument provided. Using default JDK version: $BUILD_JDK_VERSION"
fi

echo "Building the Docker image with JDK $BUILD_JDK_VERSION..."
docker build --build-arg OPENJDK_VERSION="$BUILD_JDK_VERSION" -t "${IMAGE_NAME}:${IMAGE_TAG}" -f Dockerfile .
echo "Docker image build process finished."
echo "Image created: ${IMAGE_NAME}:${IMAGE_TAG}"
