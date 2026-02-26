#!/bin/bash
set -e

IMAGE_NAME="android-in-docker"
# IMAGE_TAG="latest"
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
    echo "  -b, --build                  Execute the docker build process"
    echo "  -C, --chrome                 Build chrome.Dockerfile instead of Dockerfile"
    echo "  -H, --ssh                    Build ssh.Dockerfile instead of Dockerfile"
    echo "  -S, --start                  Start docker compose up --build after building the image"
    echo "  -P, --publish                Build and Push multi-arch images to Docker Hub (requires docker login)"
    echo "  -m, --multi-arch             Enable multi-arch mode (builds/pushes for amd64 and arm64)"
    echo "  --latest                     Tag the image as 'latest'"
    echo "  --no-snapshot                Do not tag the image as 'snapshot' (snapshot is tagged by default)"
    echo "  -h, --help                   Display this help message"
    exit 1
}

# Parse arguments
CREATE_ENV=false
EXECUTE_BUILD=false
BUILD_CHROME=false
BUILD_SSH=false
START_CONTAINER=false
PUBLISH=false
MULTI_ARCH=false
DOCKER_USERNAME=""
JDK_VERSION=""
VNC_PASSWORD=""
SYS_IMG_PKG=""
TAG_LATEST=false
TAG_SNAPSHOT=true

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
        -b|--build)
            EXECUTE_BUILD=true
            ;;
        -C|--chrome)
            BUILD_CHROME=true
            ;;
        -H|--ssh)
            BUILD_SSH=true
            ;;
        -S|--start)
            START_CONTAINER=true
            ;;
        -P|--publish)
            PUBLISH=true
            ;;
        -m|--multi-arch)
            MULTI_ARCH=true
            ;;
        --latest)
            TAG_LATEST=true
            ;;
        --no-snapshot)
            TAG_SNAPSHOT=false
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

# Get base image version from Dockerfile (supports ubuntu: or debian:)
if [ -f "Dockerfile" ]; then
    BASE_VERSION=$(grep "^FROM " Dockerfile | cut -d':' -f2 | tr -d '\r' | tr -d ' ')
    # Extract USERNAME from Dockerfile (ARG USERNAME=...)
    DF_USERNAME=$(grep "^ARG USERNAME=" Dockerfile | cut -d'=' -f2 | tr -d '\r' | tr -d ' ')
    CONTAINER_USER="${DF_USERNAME:-debian}"
else
    BASE_VERSION="unknown"
    CONTAINER_USER="debian"
fi
CONTAINER_HOME="/home/${CONTAINER_USER}"

# Get current date with timestamp
CURRENT_DATE=$(date +%Y%m%d%H%M%S)

# Load existing .env if present
if [ -f "$ENV_FILE" ]; then
    echo "Loading configuration from $ENV_FILE..."
    # We use a temporary file to source to avoid exporting variables to the current shell if we didn't want to, 
    # but here we do want them.
    # However, we must be careful not to overwrite args passed via command line if we want args to take precedence.
    # Strategy: Source env, then re-apply args if they were set.
    source "$ENV_FILE"
fi

# Re-apply command line arguments if valid (overriding .env)
[ -n "$DOCKER_USERNAME" ] && DOCKER_USERNAME="$DOCKER_USERNAME"
[ -n "$JDK_VERSION" ] && OPENJDK_VERSION="$JDK_VERSION"
[ -n "$VNC_PASSWORD" ] && VNC_PASSWD="$VNC_PASSWORD"
# SYS_IMG_PKG from args overrides the default legacy entry in .env
[ -n "$SYS_IMG_PKG" ] && SYS_IMG_PKG="$SYS_IMG_PKG"

# Set defaults if still empty
OPENJDK_VERSION="${OPENJDK_VERSION:-$DEFAULT_JDK_VERSION}"
VNC_PASSWD="${VNC_PASSWD:-$DEFAULT_VNC_PASSWORD}"
SYS_IMG_PKG="${SYS_IMG_PKG:-$DEFAULT_SYS_IMG_PKG}"


# If creating env, handle interactive mode
if [ "$CREATE_ENV" = true ]; then
    read -p "Enter OpenJDK version (default: $OPENJDK_VERSION): " INPUT_VERSION
    OPENJDK_VERSION="${INPUT_VERSION:-$OPENJDK_VERSION}"
    
    read -p "Enter VNC password (default: $VNC_PASSWD, enter 'r' for random): " INPUT_PASSWORD
    if [ "$INPUT_PASSWORD" = "r" ]; then
        VNC_PASSWD=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 16)
        echo "Generated random VNC password: $VNC_PASSWD"
    else
        VNC_PASSWD="${INPUT_PASSWORD:-$VNC_PASSWD}"
    fi

    echo "--- Docker Hub Configuration ---"
    read -p "Enter Docker Hub Username (optional, required for publish): " INPUT_DOCKER_USERNAME
    DOCKER_USERNAME="${INPUT_DOCKER_USERNAME:-$DOCKER_USERNAME}"

    echo "--- System Image Configuration ---"
    read -p "Enter System Image Package (default: $SYS_IMG_PKG): " INPUT_SysImg
    SYS_IMG_PKG="${INPUT_SysImg:-$SYS_IMG_PKG}"

    # Calculate IMAGE_TAG
    IMAGE_TAG="openjdk${OPENJDK_VERSION}.${BASE_VERSION}.${CURRENT_DATE}"

    echo "Updating $ENV_FILE..."
    # Helper to write or update var in file
    update_env_var() {
        local key=$1
        local val=$2
        local file=$3
        if grep -q "^${key}=" "$file"; then
            sed -i "s|^${key}=.*|${key}=\"${val}\"|" "$file"
        else
            echo "${key}=\"${val}\"" >> "$file"
        fi
    }

    # Initialize file if not exists
    touch "$ENV_FILE"

    update_env_var "DOCKER_USERNAME" "$DOCKER_USERNAME" "$ENV_FILE"
    update_env_var "OPENJDK_VERSION" "$OPENJDK_VERSION" "$ENV_FILE"
    update_env_var "VNC_PASSWD" "$VNC_PASSWD" "$ENV_FILE"
    update_env_var "SYS_IMG_PKG" "$SYS_IMG_PKG" "$ENV_FILE"
    update_env_var "IMAGE_TAG" "$IMAGE_TAG" "$ENV_FILE"
    update_env_var "CONTAINER_HOME" "$CONTAINER_HOME" "$ENV_FILE"
    
    echo ".env file updated."
else
    # Non-interactive Mode: Just calculate tag if not present or needs refresh? 
    # Actually, if we are just building, we rely on .env values.
    # If IMAGE_TAG is not in .env, we generate one temporarily for this build?
    if [ -z "$IMAGE_TAG" ]; then
         IMAGE_TAG="openjdk${OPENJDK_VERSION}.${BASE_VERSION}.${CURRENT_DATE}"
    fi
fi


# Prepend Docker Username to Image Name if set
if [ -n "$DOCKER_USERNAME" ]; then
    IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}"
fi


if [ "$PUBLISH" = true ]; then
    echo "Publisher mode enabled. Building and Pushing Multi-Arch Images (amd64, arm64)..."
    
    # Select Dockerfile based on chrome or ssh flag
    DOCKERFILE="Dockerfile"
    if [ "$BUILD_CHROME" = true ]; then
        echo "Can't publish chrome flavor image"
        exit 1
    elif [ "$BUILD_SSH" = true ]; then
        echo "Can't publish ssh flavor image"
        exit 1
    fi
    
    # Ensure buildx is available and use it
    # We assume 'docker buildx' is available. 
    # Create a new builder if using multi-arch to ensure isolation or use default if supported
    # docker buildx create --use || true

    BUILD_TAGS=("-t" "${IMAGE_NAME}:${IMAGE_TAG}")
    [ "$TAG_LATEST" = true ] && BUILD_TAGS+=("-t" "${IMAGE_NAME}:latest")
    [ "$TAG_SNAPSHOT" = true ] && BUILD_TAGS+=("-t" "${IMAGE_NAME}:snapshot")

    docker buildx build \
        --platform linux/amd64,linux/arm64 \
        --build-arg OPENJDK_VERSION="$OPENJDK_VERSION" \
        "${BUILD_TAGS[@]}" \
        --push \
        -f "$DOCKERFILE" .

    echo "Multi-arch build and push finished."
    echo "Image pushed: ${IMAGE_NAME}:${IMAGE_TAG}"
    echo "Cleaning up dangling images..."
    docker image prune -f

elif [ "$EXECUTE_BUILD" = true ]; then   
    echo "Building the Docker image with JDK $OPENJDK_VERSION..."
    # Show which version we're building
    if [ "$BUILD_CHROME" = true ]; then
        echo "Building Chrome version using chrome.Dockerfile"
    elif [ "$BUILD_SSH" = true ]; then
        echo "Building SSH version using ssh.Dockerfile"
    else
        echo "Building standard version using Dockerfile"
    fi
    echo "Building locally for current architecture..."
    BUILD_TAGS=("-t" "${IMAGE_NAME}:${IMAGE_TAG}")
    [ "$TAG_LATEST" = true ] && BUILD_TAGS+=("-t" "${IMAGE_NAME}:latest")
    [ "$TAG_SNAPSHOT" = true ] && BUILD_TAGS+=("-t" "${IMAGE_NAME}:snapshot")

    # Select Dockerfile based on chrome or ssh flag
    DOCKERFILE="Dockerfile"
    SPECIAL_TAG_SUFFIX=""
    if [ "$BUILD_CHROME" = true ]; then
        DOCKERFILE="chrome.Dockerfile"
        SPECIAL_TAG_SUFFIX="-chrome"
    elif [ "$BUILD_SSH" = true ]; then
        DOCKERFILE="ssh.Dockerfile"
        SPECIAL_TAG_SUFFIX="-ssh"
    fi
    
    # Modify tags to include special suffix for chrome/ssh flavors
    BUILD_TAGS_FLAVOR=()
    for tag_option in "${BUILD_TAGS[@]}"; do
        if [[ "$tag_option" == "-t" ]]; then
            continue
        fi
        
        if [[ "$tag_option" == *":"* ]]; then
            # Extract image name and tag
            image_part="${tag_option%:*}"
            tag_part="${tag_option#*:}"
            # Add special suffix before the tag
            if [[ "$tag_part" != "latest" && "$tag_part" != "snapshot" ]]; then
                # For versioned tags, add the flavor suffix
                modified_tag="${image_part}:${tag_part}${SPECIAL_TAG_SUFFIX}"
            else
                # For latest/snapshot tags, just add the suffix to the tag name
                modified_tag="${image_part}:${tag_part}${SPECIAL_TAG_SUFFIX}"
            fi
            BUILD_TAGS_FLAVOR+=("-t" "$modified_tag")
        else
            BUILD_TAGS_FLAVOR+=("$tag_option")
        fi
    done

    docker build \
        --build-arg OPENJDK_VERSION="$OPENJDK_VERSION" \
        "${BUILD_TAGS_FLAVOR[@]}" \
        -f "$DOCKERFILE" .

    echo "Docker image build process finished."
    echo "Image created: ${IMAGE_NAME}:${IMAGE_TAG}${SPECIAL_TAG_SUFFIX}"
    [ "$TAG_LATEST" = true ] && echo "Also tagged as: ${IMAGE_NAME}:latest${SPECIAL_TAG_SUFFIX}"
    [ "$TAG_SNAPSHOT" = true ] && echo "Also tagged as: ${IMAGE_NAME}:snapshot${SPECIAL_TAG_SUFFIX}"
    echo "Cleaning up dangling images..."
    docker image prune -f
fi

# Start container if requested
if [ "$START_CONTAINER" = true ]; then
    echo ""
    # Check if chrome or ssh flag is set and use appropriate docker-compose file
    if [ "$BUILD_CHROME" = true ]; then
        COMPOSE_FILES="-f docker-compose.yml -f docker-compose.chrome.yml"
        echo "Starting docker compose with chrome configuration..."
        if docker compose $COMPOSE_FILES up -d --build; then
            echo "Docker compose with Chrome configuration started successfully."
            echo "You can access the Android emulator via:"
            echo "  - Web VNC: http://localhost:6080/vnc.html"
            echo "  - VNC direct: localhost:5901"
            echo "  - Appium: http://localhost:4723/inspector"
        else
            echo "Failed to start docker compose with Chrome configuration."
        fi
    elif [ "$BUILD_SSH" = true ]; then
        COMPOSE_FILES="-f docker-compose.yml -f docker-compose.ssh.yml"
        echo "Starting docker compose with SSH configuration..."
        if docker compose $COMPOSE_FILES up -d --build; then
            echo "Docker compose with SSH configuration started successfully."
            echo "You can access the Android emulator via:"
            echo "  - Web VNC: http://localhost:6080/vnc.html"
            echo "  - VNC direct: localhost:5901"
            echo "  - Appium: http://localhost:4723/inspector"
            echo "  - SSH: localhost:2222 (username: debian, password: 123456)"
        else
            echo "Failed to start docker compose with SSH configuration."
        fi
    else
        # 启动并检查是否成功，如果成功显示下面的log
        if docker compose up -d --build; then
            echo "Docker compose started successfully."
            echo "You can access the Android emulator via:"
            echo "  - Web VNC: http://localhost:6080/vnc.html"
            echo "  - VNC direct: localhost:5901"
            echo "  - Appium: http://localhost:4723/inspector"
        else
            echo "Failed to start docker compose."
        fi
    fi
fi
