#!/bin/bash
set -e

IMAGE_NAME="android-in-docker"
# IMAGE_TAG="latest"
ENV_FILE=".env"
DEFAULT_JDK_VERSION="21"
DEFAULT_VNC_PASSWORD="password"
DEFAULT_SYS_IMG_PKG="system-images;android-36;google_apis;x86_64"
DEFAULT_DESKTOP_TYPE="xfce"
DEFAULT_BASE_SYSTEM="debian"
DEFAULT_BASE_VERSION="trixie"

validate_tag_time() {
    local value=$1
    [[ "$value" =~ ^[0-9]{12,14}$ ]]
}

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -j, --jdk-version <version>  Specify the OpenJDK version (default: $DEFAULT_JDK_VERSION)"
    echo "  -p, --password <password>    Specify the VNC password (default: $DEFAULT_VNC_PASSWORD)"
    echo "  -s, --system-image <package> Specify the System Image Package (default: $DEFAULT_SYS_IMG_PKG)"
    echo "  -t, --desktop-type <type>    Specify the Desktop Type (xfce, lxqt, mate) (default: $DEFAULT_DESKTOP_TYPE)"
    echo "  -z, --timezone <timezone>    Specify the timezone (default: auto-detect from host)"
    echo "  --base-system <system>       Specify the base system (default: $DEFAULT_BASE_SYSTEM)"
    echo "  --base-version <version>     Specify the base version (default: $DEFAULT_BASE_VERSION)"
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
BASE_SYSTEM_INPUT=""
BASE_VERSION_INPUT=""
TIMEZONE_INPUT=""
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
        --base-system)
            BASE_SYSTEM_INPUT="$2"
            shift
            ;;
        --base-version)
            BASE_VERSION_INPUT="$2"
            shift
            ;;
        -z|--timezone)
            TIMEZONE_INPUT="$2"
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

# Base system and version are parameterized (base.Dockerfile always exists)

if [ -f "Dockerfile" ]; then
    # Extract USERNAME from Dockerfile (ARG USERNAME=...)
    DF_USERNAME=$(grep "^ARG USERNAME=" Dockerfile | cut -d'=' -f2 | tr -d '\r' | tr -d ' ')
    CONTAINER_USER="${DF_USERNAME:-debian}"
else
    CONTAINER_USER="debian"
fi
CONTAINER_HOME="/home/${CONTAINER_USER}"

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
[ -n "$BASE_SYSTEM_INPUT" ] && BASE_SYSTEM="$BASE_SYSTEM_INPUT"
[ -n "$BASE_VERSION_INPUT" ] && BASE_VERSION="$BASE_VERSION_INPUT"

# Set defaults if still empty
OPENJDK_VERSION="${OPENJDK_VERSION:-$DEFAULT_JDK_VERSION}"
VNC_PASSWD="${VNC_PASSWD:-$DEFAULT_VNC_PASSWORD}"
SYS_IMG_PKG="${SYS_IMG_PKG:-$DEFAULT_SYS_IMG_PKG}"
DESKTOP_TYPE="${DESKTOP_TYPE:-$DEFAULT_DESKTOP_TYPE}"
BASE_SYSTEM="${BASE_SYSTEM:-$DEFAULT_BASE_SYSTEM}"
BASE_VERSION="${BASE_VERSION:-$DEFAULT_BASE_VERSION}"

# Timezone: use CLI argument if provided, otherwise detect from host
if [ -n "$TIMEZONE_INPUT" ]; then
    SYSTEM_TIMEZONE="$TIMEZONE_INPUT"
    echo "Timezone set from argument: $SYSTEM_TIMEZONE"
else
    SYSTEM_TIMEZONE=$(cat /etc/timezone 2>/dev/null || timedatectl show --property=Timezone --value 2>/dev/null || echo "Asia/Shanghai")
    echo "System timezone detected from host: $SYSTEM_TIMEZONE"
fi

# Calculate Tag Base (both full and omitted versions)
calculate_tag_base() {
    # Full version always includes system, version and desktop type
    TAG_FULL="${BASE_SYSTEM}-${BASE_VERSION}-${DESKTOP_TYPE}-openjdk${OPENJDK_VERSION}"

    # Omitted version removes defaults (debian, trixie, xfce, openjdk21)
    local parts=()
    [ "$BASE_SYSTEM" != "debian" ] && parts+=("$BASE_SYSTEM")
    [ "$BASE_VERSION" != "trixie" ] && parts+=("$BASE_VERSION")
    [ "$DESKTOP_TYPE" != "xfce" ] && parts+=("$DESKTOP_TYPE")
    [ "$OPENJDK_VERSION" != "21" ] || [ "${#parts[@]}" -eq 0 ] && parts+=("openjdk${OPENJDK_VERSION}")
    
    # If all parts were defaults, TAG_BASE would be empty without the check above.
    # The [ "${#parts[@]}" -eq 0 ] ensures at least jdk version is present if others are omitted,
    # OR if jdk is not 21 it's always added.
    # If the user wants to omit openjdk21 specifically:
    parts=()
    [ "$BASE_SYSTEM" != "debian" ] && parts+=("$BASE_SYSTEM")
    [ "$BASE_VERSION" != "trixie" ] && parts+=("$BASE_VERSION")
    [ "$DESKTOP_TYPE" != "xfce" ] && parts+=("$DESKTOP_TYPE")
    [ "$OPENJDK_VERSION" != "21" ] && parts+=("openjdk${OPENJDK_VERSION}")
    
    if [ ${#parts[@]} -eq 0 ]; then
        TAG_BASE="latest" # Or something minimal if all are default
        # However, IMAGE_TAG uses ${TAG_BASE}-${IMAGE_TAG_TIME}
        # Let's make TAG_BASE empty if all are default, and handle the dash.
        TAG_BASE=""
    else
        TAG_BASE=$(IFS=-; echo "${parts[*]}")
    fi
}

calculate_tag_base

TIME_FALLBACK="$(date +%Y%m%d%H%M%S)"

if ! validate_tag_time "$IMAGE_TAG_TIME"; then
    [ -n "$IMAGE_TAG_TIME" ] && echo "Warning: IMAGE_TAG_TIME '$IMAGE_TAG_TIME' is invalid, fallback to runtime timestamp."
    IMAGE_TAG_TIME="$TIME_FALLBACK"
fi

if [ -n "$TAG_BASE" ]; then
    IMAGE_TAG="${TAG_BASE}-${IMAGE_TAG_TIME}"
else
    IMAGE_TAG="${IMAGE_TAG_TIME}"
fi


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

    # Recalculate tag components and keep existing timestamp unless missing/invalid.
    calculate_tag_base
    if ! validate_tag_time "$IMAGE_TAG_TIME"; then
        IMAGE_TAG_TIME="$TIME_FALLBACK"
    fi
    if [ -n "$TAG_BASE" ]; then
        IMAGE_TAG="${TAG_BASE}-${IMAGE_TAG_TIME}"
    else
        IMAGE_TAG="${IMAGE_TAG_TIME}"
    fi

    echo "Updating $ENV_FILE..."

    update_env_var "DOCKER_USERNAME" "$DOCKER_USERNAME" "$ENV_FILE"
    update_env_var "OPENJDK_VERSION" "$OPENJDK_VERSION" "$ENV_FILE"
    update_env_var "VNC_PASSWD" "$VNC_PASSWD" "$ENV_FILE"
    update_env_var "SYS_IMG_PKG" "$SYS_IMG_PKG" "$ENV_FILE"
    update_env_var "BASE_SYSTEM" "$BASE_SYSTEM" "$ENV_FILE"
    update_env_var "BASE_VERSION" "$BASE_VERSION" "$ENV_FILE"
    update_env_var "IMAGE_TAG_TIME" "$IMAGE_TAG_TIME" "$ENV_FILE"
    
    echo ".env file updated."
else
    echo "Using existing configuration from .env or defaults."
fi


# Prepend Docker Username to Image Name if set
if [ -n "$DOCKER_USERNAME" ]; then
    IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}"
fi


# Global array to accumulate all built tags (format: "dockerfile|tag")
ALL_BUILT_TAGS=()

# --- Build Function ---
run_build() {
    local df=$1
    local name=$2
    local suffix=$3
    local add_openjdk_tag=$4
    local add_full_prefix_tag=${5:-true}

    echo "--------------------------------------------------------"
    echo "Building: $name (Dockerfile: $df, Suffix: '$suffix')"

    # Local prefixes for this build flavor
    local base_prefix=""
    if [ -n "$TAG_BASE" ]; then
        base_prefix="${TAG_BASE}${suffix}"
    else
        # If TAG_BASE is empty, use suffix without leading dash if possible, or just empty
        base_prefix="${suffix#-}"
    fi

    local full_prefix="${TAG_FULL}${suffix}"
    local should_add_full_prefix=false

    if [ "$add_full_prefix_tag" = true ] && [ "$base_prefix" != "$full_prefix" ]; then
        echo "Adding full prefix tag for $name with full prefix '$full_prefix' because it differs from base prefix '$base_prefix'"
        should_add_full_prefix=true
    fi

    add_tag_pair() {
        local tag_suffix=$1
        local tag_reason=${2:-"Primary timestamped tag"}
        local full_tag_name=""
        
        if [ -n "$base_prefix" ]; then
            full_tag_name="${name}:${base_prefix}${tag_suffix}"
        else
            # If both are empty, and tag_suffix is like -2024..., remove leading dash
            full_tag_name="${name}:${tag_suffix#-}"
        fi

        tags+=("-t" "$full_tag_name")
        echo "Added tag: $full_tag_name (Reason: $tag_reason)"
        ALL_BUILT_TAGS+=("${df}|${full_tag_name}|${tag_reason}")

        if [ "$should_add_full_prefix" = true ]; then
            local full_os_tag="${name}:${full_prefix}${tag_suffix}"
            echo "Added tag: $full_os_tag (Reason: $tag_reason, with full OS prefix)"
            tags+=("-t" "$full_os_tag")
            ALL_BUILT_TAGS+=("${df}|${full_os_tag}|${tag_reason} (with full OS prefix)")
        fi
    }
    
    # Define common tags (primary timestamped tags)
    local tags=()
    add_tag_pair "-${IMAGE_TAG_TIME}" "Primary timestamped tag"
    
    # Add flavor-specific latest and snapshot tags
    if [ "$TAG_LATEST" = true ]; then
        add_tag_pair "-latest" "Latest release tag"
    fi
    if [ "$TAG_SNAPSHOT" = true ]; then
        add_tag_pair "-snapshot" "Snapshot development tag"
    fi
    
    # Add plain tags ONLY for the default flavor configuration (e.g., :latest, :dev-latest)
    if [ "$BASE_SYSTEM" = "debian" ] && [ "$BASE_VERSION" = "trixie" ] && [ "$DESKTOP_TYPE" = "xfce" ]; then
        local plain_indicator="${suffix#-}" # Remove leading dash (e.g., "-dev" -> "dev")
        if [ -n "$plain_indicator" ]; then
            local reason="Plain tag for $plain_indicator flavor (default OS/Desktop)"
            echo "Adding plain tags for $name with indicator '$plain_indicator'"
            if [ "$TAG_LATEST" = true ]; then
                local t="${name}:${plain_indicator}-latest"
                tags+=("-t" "$t")
                ALL_BUILT_TAGS+=("${df}|${t}|${reason}")
            fi
            if [ "$TAG_SNAPSHOT" = true ]; then
                local t="${name}:${plain_indicator}-snapshot"
                tags+=("-t" "$t")
                ALL_BUILT_TAGS+=("${df}|${t}|${reason}")
            fi
        else
            local reason="Plain tag for default flavor (default OS/Desktop)"
            echo "Adding plain tags for $name without indicator"
            if [ "$TAG_LATEST" = true ]; then
                local t="${name}:latest"
                tags+=("-t" "$t")
                ALL_BUILT_TAGS+=("${df}|${t}|${reason}")
            fi
            if [ "$TAG_SNAPSHOT" = true ]; then
                local t="${name}:snapshot"
                tags+=("-t" "$t")
                ALL_BUILT_TAGS+=("${df}|${t}|${reason}")
            fi
        fi
    fi

    # Add stable alias (e.g., :openjdk21 or :mate-openjdk21-dev)
    if [ "$add_openjdk_tag" = true ]; then
        add_tag_pair "" "Stable version alias (OpenJDK only)"
    fi

    # Execute the build
    if [ "$PUBLISH" = true ]; then
        docker buildx build \
            --platform linux/amd64,linux/arm64 \
            --build-arg BASE_SYSTEM="$BASE_SYSTEM" \
            --build-arg BASE_VERSION="$BASE_VERSION" \
            --build-arg OPENJDK_VERSION="$OPENJDK_VERSION" \
            --build-arg DESKTOP_TYPE="$DESKTOP_TYPE" \
            --build-arg TIMEZONE="$SYSTEM_TIMEZONE" \
            "${tags[@]}" \
            --push \
            -f "$df" .
    elif [ "$EXECUTE_BUILD" = true ]; then
        docker build \
            --build-arg BASE_SYSTEM="$BASE_SYSTEM" \
            --build-arg BASE_VERSION="$BASE_VERSION" \
            --build-arg OPENJDK_VERSION="$OPENJDK_VERSION" \
            --build-arg DESKTOP_TYPE="$DESKTOP_TYPE" \
            --build-arg TIMEZONE="$SYSTEM_TIMEZONE" \
            "${tags[@]}" \
            -f "$df" .
    fi
}

if [ "$PUBLISH" = true ] || [ "$EXECUTE_BUILD" = true ]; then
    # Automatically build the dependency chain
    if [ "$BUILD_BASE" = true ]; then
        run_build "base.Dockerfile" "${IMAGE_NAME}-base" "" true true
    else
        echo "Automatically building dependencies..."
        # All target images depend on the base image
        run_build "base.Dockerfile" "${IMAGE_NAME}-base" "" true true
        
        if [ "$BUILD_DEV" = true ]; then
            run_build "Dockerfile" "${IMAGE_NAME}" "" false true
            
            run_build "dev.Dockerfile" "${IMAGE_NAME}" "-dev" false true
        else
            run_build "Dockerfile" "${IMAGE_NAME}" "" false true
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

# Print summary of all built tags grouped by Dockerfile at the very end
if [ ${#ALL_BUILT_TAGS[@]} -gt 0 ]; then
    echo ""
    echo "========================================================"
    echo "Final Summary of All Built Tags:"
    current_df=""
    for entry in "${ALL_BUILT_TAGS[@]}"; do
        # Format: dockerfile|tag|reason
        df_name="${entry%%|*}"
        tag_info="${entry#*|}"
        tag_name="${tag_info%%|*}"
        tag_reason="${tag_info#*|}"

        if [ "$df_name" != "$current_df" ]; then
            current_df="$df_name"
            echo "  [$current_df]"
        fi
        echo "    - $tag_name"
        echo "      (Reason: $tag_reason)"
    done
    echo "========================================================"
fi
