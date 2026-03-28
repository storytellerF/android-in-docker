#!/bin/bash
set -e

IMAGE_NAME="android-in-docker"
# IMAGE_TAG="latest"
ENV_FILE=".env"
DEFAULT_JDK_VERSION="21"
DEFAULT_VNC_PASSWORD="password"
DEFAULT_SYS_IMG_PKG="system-images;android-36;google_apis;x86_64"
DEFAULT_DESKTOP_TYPE="xfce"

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -j, --jdk-version <version>  Specify the OpenJDK version (default: $DEFAULT_JDK_VERSION)"
    echo "  -p, --password <password>    Specify the VNC password (default: $DEFAULT_VNC_PASSWORD)"
    echo "  -s, --system-image <package> Specify the System Image Package (default: $DEFAULT_SYS_IMG_PKG)"
    echo "  -t, --desktop-type <type>    Specify the Desktop Type (xfce, lxqt, mate) (default: $DEFAULT_DESKTOP_TYPE)"
    echo "  -c, --create-env             Create or overwrite the .env file with the specified or default values"
    echo "  -b, --build                  Execute the docker build process"
    echo "  -B, --base                   Build the base image from base.Dockerfile"
    echo "  -D, --dev                    Build dev.Dockerfile instead of Dockerfile (includes SSH, Chrome, Android Studio)"
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
BUILD_BASE=false
BUILD_DEV=false
START_CONTAINER=false
PUBLISH=false
MULTI_ARCH=false
DOCKER_USERNAME=""
JDK_VERSION=""
VNC_PASSWORD=""
SYS_IMG_PKG=""
DESKTOP_TYPE_INPUT=""
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
        -t|--desktop-type)
            DESKTOP_TYPE_INPUT="$2"
            shift
            ;;
        -c|--create-env)
            CREATE_ENV=true
            ;;
        -b|--build)
            EXECUTE_BUILD=true
            ;;
        -B|--base)
            BUILD_BASE=true
            ;;
        -D|--dev)
            BUILD_DEV=true
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

# Get base image version from base.Dockerfile or Dockerfile (preferring base.Dockerfile)
if [ -f "base.Dockerfile" ]; then
    BASE_VERSION=$(grep "^FROM " base.Dockerfile | cut -d':' -f2 | cut -d'-' -f1 | tr -d '\r' | tr -d ' ')
elif [ -f "Dockerfile" ]; then
    BASE_VERSION=$(grep "^FROM " Dockerfile | cut -d':' -f2 | cut -d'-' -f1 | tr -d '\r' | tr -d ' ')
else
    BASE_VERSION="unknown"
fi

if [ -f "Dockerfile" ]; then
    # Extract USERNAME from Dockerfile (ARG USERNAME=...)
    DF_USERNAME=$(grep "^ARG USERNAME=" Dockerfile | cut -d'=' -f2 | tr -d '\r' | tr -d ' ')
    CONTAINER_USER="${DF_USERNAME:-debian}"
else
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
[ -n "$DESKTOP_TYPE_INPUT" ] && DESKTOP_TYPE="$DESKTOP_TYPE_INPUT"

# Set defaults if still empty
OPENJDK_VERSION="${OPENJDK_VERSION:-$DEFAULT_JDK_VERSION}"
VNC_PASSWD="${VNC_PASSWD:-$DEFAULT_VNC_PASSWORD}"
SYS_IMG_PKG="${SYS_IMG_PKG:-$DEFAULT_SYS_IMG_PKG}"
DESKTOP_TYPE="${DESKTOP_TYPE:-$DEFAULT_DESKTOP_TYPE}"

# Calculate Tag Base (both full and omitted versions)
calculate_tag_base() {
    # Full version always includes system and desktop type
    TAG_FULL="${BASE_VERSION}-${DESKTOP_TYPE}-openjdk${OPENJDK_VERSION}"

    # Omitted version removes defaults (trixie, xfce)
    local parts=()
    [ "$BASE_VERSION" != "trixie" ] && parts+=("$BASE_VERSION")
    [ "$DESKTOP_TYPE" != "xfce" ] && parts+=("$DESKTOP_TYPE")
    parts+=("openjdk${OPENJDK_VERSION}")
    TAG_BASE=$(IFS=-; echo "${parts[*]}")
}

calculate_tag_base


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
    read -p "Enter Docker Hub Username (default: $DOCKER_USERNAME, optional, required for publish): " INPUT_DOCKER_USERNAME
    DOCKER_USERNAME="${INPUT_DOCKER_USERNAME:-$DOCKER_USERNAME}"

    echo "--- System Image Configuration ---"
    read -p "Enter System Image Package (default: $SYS_IMG_PKG): " INPUT_SysImg
    SYS_IMG_PKG="${INPUT_SysImg:-$SYS_IMG_PKG}"

    echo "--- Desktop Configuration ---"
    read -p "Enter Desktop Type (xfce, lxqt, mate) (default: $DESKTOP_TYPE): " INPUT_DesktopType
    DESKTOP_TYPE="${INPUT_DesktopType:-$DESKTOP_TYPE}"

    # Recalculate Tag Base after potential prompts
    calculate_tag_base
    IMAGE_TAG="${TAG_BASE}-${CURRENT_DATE}"

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
    update_env_var "DESKTOP_TYPE" "$DESKTOP_TYPE" "$ENV_FILE"
    update_env_var "IMAGE_TAG" "$IMAGE_TAG" "$ENV_FILE"
    update_env_var "CONTAINER_HOME" "$CONTAINER_HOME" "$ENV_FILE"
    
    echo ".env file updated."
else
    # Non-interactive Mode: Just calculate tag if not present or needs refresh? 
    # Actually, if we are just building, we rely on .env values.
    # If IMAGE_TAG is not in .env, we generate one temporarily for this build?
    # If any override was provided, or if IMAGE_TAG is not set, calculate it.
    # Non-interactive Mode: Recalculate Tag Base and IMAGE_TAG if needed
    calculate_tag_base
    if [ -n "$JDK_VERSION" ] || [ -n "$DESKTOP_TYPE_INPUT" ] || [ -z "$IMAGE_TAG" ]; then
         IMAGE_TAG="${TAG_BASE}-${CURRENT_DATE}"
    fi
fi


# Prepend Docker Username to Image Name if set
if [ -n "$DOCKER_USERNAME" ]; then
    IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}"
fi


# --- Build Function ---
run_build() {
    local df=$1
    local name=$2
    local suffix=$3
    local add_openjdk_tag=$4

    echo "--------------------------------------------------------"
    echo "Building: $name (Dockerfile: $df, Suffix: '$suffix')"
    echo "--------------------------------------------------------"

    # Local prefixes for this build flavor
    local base_prefix="${TAG_BASE}${suffix}"
    local full_prefix="${TAG_FULL}${suffix}"
    
    # Define common tags (primary timestamped tags)
    local tags=("-t" "${name}:${base_prefix}-${CURRENT_DATE}")
    if [ "$base_prefix" != "$full_prefix" ]; then
         tags+=("-t" "${name}:${full_prefix}-${CURRENT_DATE}")
    fi
    
    # Add flavor-specific latest and snapshot tags
    if [ "$TAG_LATEST" = true ]; then
        tags+=("-t" "${name}:${base_prefix}-latest")
        [ "$base_prefix" != "$full_prefix" ] && tags+=("-t" "${name}:${full_prefix}-latest")
    fi
    if [ "$TAG_SNAPSHOT" = true ]; then
        tags+=("-t" "${name}:${base_prefix}-snapshot")
        [ "$base_prefix" != "$full_prefix" ] && tags+=("-t" "${name}:${full_prefix}-snapshot")
    fi
    
    # Add plain tags ONLY for the default flavor configuration (e.g., :latest, :dev-latest)
    if [ "$BASE_VERSION" = "trixie" ] && [ "$DESKTOP_TYPE" = "xfce" ]; then
        local plain_indicator="${suffix#-}" # Remove leading dash (e.g., "-dev" -> "dev")
        if [ -n "$plain_indicator" ]; then
            [ "$TAG_LATEST" = true ] && tags+=("-t" "${name}:${plain_indicator}-latest")
            [ "$TAG_SNAPSHOT" = true ] && tags+=("-t" "${name}:${plain_indicator}-snapshot")
        else
            [ "$TAG_LATEST" = true ] && tags+=("-t" "${name}:latest")
            [ "$TAG_SNAPSHOT" = true ] && tags+=("-t" "${name}:snapshot")
        fi
    fi

    # Add stable alias (e.g., :openjdk21 or :mate-openjdk21-dev)
    if [ "$add_openjdk_tag" = true ]; then
        tags+=("-t" "${name}:${base_prefix}")
        [ "$base_prefix" != "$full_prefix" ] && tags+=("-t" "${name}:${full_prefix}")
    fi

    # Execute the build
    if [ "$PUBLISH" = true ]; then
        docker buildx build \
            --platform linux/amd64,linux/arm64 \
            --build-arg OPENJDK_VERSION="$OPENJDK_VERSION" \
            --build-arg DESKTOP_TYPE="$DESKTOP_TYPE" \
            --build-arg BASE_TAG="$IMAGE_TAG" \
            "${tags[@]}" \
            --push \
            -f "$df" .
    elif [ "$EXECUTE_BUILD" = true ]; then
        docker build \
            --build-arg OPENJDK_VERSION="$OPENJDK_VERSION" \
            --build-arg DESKTOP_TYPE="$DESKTOP_TYPE" \
            --build-arg BASE_TAG="$IMAGE_TAG" \
            "${tags[@]}" \
            -f "$df" .
    fi
}

if [ "$PUBLISH" = true ] || [ "$EXECUTE_BUILD" = true ]; then
    # Automatically build the dependency chain
    if [ "$BUILD_BASE" = true ]; then
        run_build "base.Dockerfile" "${IMAGE_NAME}-base" "" true
    else
        echo "Automatically building dependencies..."
        # All target images depend on the base image
        run_build "base.Dockerfile" "${IMAGE_NAME}-base" "" true
        
        if [ "$BUILD_DEV" = true ]; then
            run_build "Dockerfile" "${IMAGE_NAME}" "" false
            
            run_build "dev.Dockerfile" "${IMAGE_NAME}" "-dev" false
        else
            run_build "Dockerfile" "${IMAGE_NAME}" "" false
        fi
    fi
    echo "Cleaning up dangling images..."
    docker image prune -f
fi

# Start container if requested
if [ "$START_CONTAINER" = true ]; then
    echo ""
    # Check if dev flag is set and use appropriate docker-compose file
    if [ "$BUILD_DEV" = true ]; then
        COMPOSE_FILES="-f docker-compose.yml -f docker-compose.dev.yml"
        # if grep -qi "microsoft" /proc/version 2>/dev/null || grep -qi "wsl" /proc/version 2>/dev/null; then
        #     COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.privileged.yml"
        #     echo "Windows/WSL environment detected, using privileged configuration."
        # else
        #     echo "Standard Linux environment detected, using KVM and chrome configuration."
        # fi
        COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.kvm.yml"
        echo "Starting docker compose with DEV configuration..."
        export IMAGE_TAG="$IMAGE_TAG"
        export CONTAINER_HOME="$CONTAINER_HOME"
        if docker compose $COMPOSE_FILES up -d --build; then
            echo "Docker compose with DEV configuration started successfully."
            # Retrieve dynamic ports
            VNC_PORT=$(docker compose $COMPOSE_FILES port android 5901 2>/dev/null | cut -d: -f2)
            NOVNC_PORT=$(docker compose $COMPOSE_FILES port android 6080 2>/dev/null | cut -d: -f2)
            APPIUM_PORT=$(docker compose $COMPOSE_FILES port android 4723 2>/dev/null | cut -d: -f2)
            SSH_PORT=$(docker compose $COMPOSE_FILES port android 22 2>/dev/null | cut -d: -f2)
            ADB_PORT=$(docker compose $COMPOSE_FILES port android 5555 2>/dev/null | cut -d: -f2)

            echo "You can access the Android emulator via:"
            [ -n "$NOVNC_PORT" ] && echo "  - Web VNC: http://localhost:${NOVNC_PORT}/vnc.html"
            [ -n "$VNC_PORT" ] && echo "  - VNC direct: localhost:${VNC_PORT}"
            [ -n "$APPIUM_PORT" ] && echo "  - Appium: http://localhost:${APPIUM_PORT}/inspector"
            [ -n "$SSH_PORT" ] && echo "  - SSH: ssh -p ${SSH_PORT} debian@localhost"
            [ -n "$ADB_PORT" ] && echo "  - ADB: adb connect localhost:${ADB_PORT}"
        else
            echo "Failed to start docker compose with DEV configuration."
        fi
    else
        # 启动并检查是否成功，如果成功显示下面的log
        COMPOSE_FILES="-f docker-compose.yml -f docker-compose.kvm.yml"
        echo "Starting standard docker compose..."
        export IMAGE_TAG="$IMAGE_TAG"
        export CONTAINER_HOME="$CONTAINER_HOME"
        if docker compose $COMPOSE_FILES up -d --build; then
            echo "Docker compose started successfully."
            # Retrieve dynamic ports
            VNC_PORT=$(docker compose $COMPOSE_FILES port android 5901 2>/dev/null | cut -d: -f2)
            NOVNC_PORT=$(docker compose $COMPOSE_FILES port android 6080 2>/dev/null | cut -d: -f2)
            APPIUM_PORT=$(docker compose $COMPOSE_FILES port android 4723 2>/dev/null | cut -d: -f2)
            ADB_PORT=$(docker compose $COMPOSE_FILES port android 5555 2>/dev/null | cut -d: -f2)

            echo "You can access the Android emulator via:"
            [ -n "$NOVNC_PORT" ] && echo "  - Web VNC: http://localhost:${NOVNC_PORT}/vnc.html"
            [ -n "$VNC_PORT" ] && echo "  - VNC direct: localhost:${VNC_PORT}"
            [ -n "$APPIUM_PORT" ] && echo "  - Appium: http://localhost:${APPIUM_PORT}/inspector"
            [ -n "$ADB_PORT" ] && echo "  - ADB: adb connect localhost:${ADB_PORT}"
        else
            echo "Failed to start docker compose."
        fi
    fi
fi
