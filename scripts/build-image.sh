#!/bin/bash
set -e

IMAGE_NAME="android-in-docker"
# IMAGE_TAG="latest"
ENV_FILE=".env"
DOCKER_ROOT="docker"
DOCKERFILE_DIR="${DOCKER_ROOT}/dockerfiles"
COMPOSE_DIR="${DOCKER_ROOT}/compose"
FINAL_DOCKERFILE="${DOCKERFILE_DIR}/Dockerfile"
DEFAULT_JDK_PROVIDER="openjdk"
DEFAULT_JDK_VERSION="21"
DEFAULT_VNC_PASSWORD="password"
DEFAULT_SYS_IMG_PKG="system-images;android-36;google_apis;x86_64"
DEFAULT_DESKTOP_TYPE="xfce"
DEFAULT_BASE_SYSTEM="debian"
DEFAULT_DEBIAN_VERSION="trixie"
DEFAULT_UBUNTU_VERSION="noble"

default_base_version_for_system() {
    case "$1" in
        debian)
            echo "$DEFAULT_DEBIAN_VERSION"
            ;;
        ubuntu)
            echo "$DEFAULT_UBUNTU_VERSION"
            ;;
        *)
            return 1
            ;;
    esac
}

default_username_for_system() {
    case "$1" in
        debian)
            echo "debian"
            ;;
        ubuntu)
            echo "ubuntu"
            ;;
        *)
            return 1
            ;;
    esac
}

supported_base_versions_for_system() {
    case "$1" in
        debian)
            echo "bookworm $DEFAULT_DEBIAN_VERSION"
            ;;
        ubuntu)
            echo "jammy $DEFAULT_UBUNTU_VERSION"
            ;;
        *)
            return 1
            ;;
    esac
}

is_supported_base_system() {
    case "$1" in
        debian|ubuntu)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

is_supported_base_version_for_system() {
    local system=$1
    local version=$2
    local supported_versions

    supported_versions=$(supported_base_versions_for_system "$system") || return 1

    for supported_version in $supported_versions; do
        if [ "$supported_version" = "$version" ]; then
            return 0
        fi
    done

    return 1
}

validate_tag_time() {
    local value=$1
    [[ "$value" =~ ^[0-9]{12,14}$ ]]
}

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --jdk-provider <provider>    Specify the JDK provider (openjdk, temurin) (default: $DEFAULT_JDK_PROVIDER)"
    echo "  -j, --jdk-version <version>  Specify the JDK version (default: $DEFAULT_JDK_VERSION)"
    echo "  -p, --password <password>    Specify the VNC password (default: $DEFAULT_VNC_PASSWORD)"
    echo "  -s, --system-image <package> Specify the System Image Package (default: $DEFAULT_SYS_IMG_PKG)"
    echo "  -t, --desktop-type <type>    Specify the Desktop Type (xfce, lxqt, mate) (default: $DEFAULT_DESKTOP_TYPE)"
    echo "  -z, --timezone <timezone>    Specify the timezone (default: auto-detect from host)"
    echo "  --cn-env                     Build the China image variant (uses ${DOCKERFILE_DIR}/standard_cn.Dockerfile and ${DOCKERFILE_DIR}/temurin_cn.Dockerfile when applicable)"
    echo "  --no-cn-env                  Build the standard image variant (default: auto-detect from timezone/locale)"
    echo "  --base-system <system>       Specify the base system (debian, ubuntu) (default: $DEFAULT_BASE_SYSTEM)"
    echo "  --base-version <version>     Specify the base version (debian: bookworm/$DEFAULT_DEBIAN_VERSION, ubuntu: jammy/$DEFAULT_UBUNTU_VERSION; default depends on --base-system)"
    echo "  -c, --create-env             Create or overwrite the .env file with the specified or default values"
    echo "  -b, --build                  Execute the docker build process"
    echo "  -D, --dev                    Build ${DOCKERFILE_DIR}/dev.Dockerfile instead of ${DOCKERFILE_DIR}/Dockerfile (includes SSH, Chrome, Android Studio)"
    echo "  -S, --start                  Start docker compose up --build after building the image"
    echo "  -K, --stop                   Stop docker compose and remove the project containers"
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
BUILD_DEV=false
START_CONTAINER=false
STOP_CONTAINER=false
PUBLISH=false
MULTI_ARCH=false
DOCKER_USERNAME=""
JDK_PROVIDER_INPUT=""
JDK_VERSION=""
VNC_PASSWORD=""
SYS_IMG_PKG=""
DESKTOP_TYPE_INPUT=""
BASE_SYSTEM_INPUT=""
BASE_VERSION_INPUT=""
TIMEZONE_INPUT=""
USE_CN_ENV_INPUT=""
TAG_LATEST=false
TAG_SNAPSHOT=true

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --jdk-provider)
            JDK_PROVIDER_INPUT="$2"
            shift
            ;;
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
        --cn-env)
            USE_CN_ENV_INPUT=true
            ;;
        --no-cn-env)
            USE_CN_ENV_INPUT=false
            ;;
        -c|--create-env)
            CREATE_ENV=true
            ;;
        -b|--build)
            EXECUTE_BUILD=true
            ;;
        -D|--dev)
            BUILD_DEV=true
            ;;
        -S|--start)
            START_CONTAINER=true
            ;;
        -K|--stop)
            STOP_CONTAINER=true
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
[ -n "$JDK_PROVIDER_INPUT" ] && JDK_PROVIDER="$JDK_PROVIDER_INPUT"
[ -n "$JDK_VERSION" ] && OPENJDK_VERSION="$JDK_VERSION"
[ -n "$VNC_PASSWORD" ] && VNC_PASSWD="$VNC_PASSWORD"
# SYS_IMG_PKG from args overrides the default legacy entry in .env
[ -n "$SYS_IMG_PKG" ] && SYS_IMG_PKG="$SYS_IMG_PKG"
[ -n "$DESKTOP_TYPE_INPUT" ] && DESKTOP_TYPE="$DESKTOP_TYPE_INPUT"
[ -n "$BASE_SYSTEM_INPUT" ] && BASE_SYSTEM="$BASE_SYSTEM_INPUT"
[ -n "$BASE_VERSION_INPUT" ] && BASE_VERSION="$BASE_VERSION_INPUT"

# Set defaults if still empty
JDK_PROVIDER="${JDK_PROVIDER:-$DEFAULT_JDK_PROVIDER}"
OPENJDK_VERSION="${OPENJDK_VERSION:-$DEFAULT_JDK_VERSION}"
VNC_PASSWD="${VNC_PASSWD:-$DEFAULT_VNC_PASSWORD}"
SYS_IMG_PKG="${SYS_IMG_PKG:-$DEFAULT_SYS_IMG_PKG}"
DESKTOP_TYPE="${DESKTOP_TYPE:-$DEFAULT_DESKTOP_TYPE}"
BASE_SYSTEM="${BASE_SYSTEM:-$DEFAULT_BASE_SYSTEM}"
if [ -z "$BASE_VERSION" ]; then
    BASE_VERSION=$(default_base_version_for_system "$BASE_SYSTEM")
fi

CONTAINER_USER=$(default_username_for_system "$BASE_SYSTEM")
CONTAINER_HOME="/home/${CONTAINER_USER}"

if ! is_supported_base_system "$BASE_SYSTEM"; then
    echo "Unsupported base system: $BASE_SYSTEM"
    echo "Supported values: debian, ubuntu"
    exit 1
fi

if ! is_supported_base_version_for_system "$BASE_SYSTEM" "$BASE_VERSION"; then
    echo "Unsupported base version '$BASE_VERSION' for base system '$BASE_SYSTEM'"
    echo "Supported versions for $BASE_SYSTEM: $(supported_base_versions_for_system "$BASE_SYSTEM")"
    exit 1
fi

case "$JDK_PROVIDER" in
    openjdk|temurin)
        ;;
    *)
        echo "Unsupported JDK provider: $JDK_PROVIDER"
        echo "Supported values: openjdk, temurin"
        exit 1
        ;;
esac

# Timezone: use CLI argument if provided, otherwise detect from host
if [ -n "$TIMEZONE_INPUT" ]; then
    SYSTEM_TIMEZONE="$TIMEZONE_INPUT"
    echo "Timezone set from argument: $SYSTEM_TIMEZONE"
else
    SYSTEM_TIMEZONE=$(cat /etc/timezone 2>/dev/null || timedatectl show --property=Timezone --value 2>/dev/null || echo "Asia/Shanghai")
    echo "System timezone detected from host: $SYSTEM_TIMEZONE"
fi

# Determine USE_CN_ENV: explicit flag takes precedence, otherwise auto-detect
if [ -n "$USE_CN_ENV_INPUT" ]; then
    USE_CN_ENV="$USE_CN_ENV_INPUT"
    echo "USE_CN_ENV set from argument: $USE_CN_ENV"
else
    _is_cn_tz=false
    _is_cn_locale=false
    if echo "$SYSTEM_TIMEZONE" | grep -qE "^(Asia/(Shanghai|Chongqing|Chungking|Harbin|Urumqi)|PRC)$"; then
        _is_cn_tz=true
    fi
    if echo "${LANG:-}${LC_ALL:-}${LC_CTYPE:-}" | grep -qi "zh"; then
        _is_cn_locale=true
    fi
    if [ "$_is_cn_tz" = true ] || [ "$_is_cn_locale" = true ]; then
        USE_CN_ENV=true
    else
        USE_CN_ENV=false
    fi
    echo "USE_CN_ENV auto-detected: $USE_CN_ENV (cn_tz=$_is_cn_tz, cn_locale=$_is_cn_locale)"
fi

# Build fully-qualified tag prefixes.
build_tag_prefix() {
    local prefix="${BASE_SYSTEM}-${BASE_VERSION}-${DESKTOP_TYPE}-${JDK_PROVIDER}${OPENJDK_VERSION}"
    if [ -n "$1" ]; then
        prefix="${prefix}-$1"
    fi
    if [ -n "$2" ]; then
        prefix="${prefix}-$2"
    fi
    echo "$prefix"
}

build_image_tag() {
    local prefix=$1
    local label=$2
    echo "${prefix}-${label}"
}

build_short_core_prefix() {
    local parts=()
    local provider_segment="${JDK_PROVIDER}${OPENJDK_VERSION}"
    local default_provider_segment="${DEFAULT_JDK_PROVIDER}${DEFAULT_JDK_VERSION}"

    [ "$BASE_SYSTEM" != "$DEFAULT_BASE_SYSTEM" ] && parts+=("$BASE_SYSTEM")
    [ "$BASE_VERSION" != "$(default_base_version_for_system "$BASE_SYSTEM")" ] && parts+=("$BASE_VERSION")
    [ "$DESKTOP_TYPE" != "$DEFAULT_DESKTOP_TYPE" ] && parts+=("$DESKTOP_TYPE")
    [ "$provider_segment" != "$default_provider_segment" ] && parts+=("$provider_segment")

    if [ ${#parts[@]} -gt 0 ]; then
        printf '%s' "$(IFS=-; echo "${parts[*]}")"
    fi
}

build_short_tag_prefix() {
    local suffix=$1
    local core_prefix
    core_prefix=$(build_short_core_prefix)

    if [ -n "$core_prefix" ] && [ -n "$suffix" ]; then
        echo "${core_prefix}-${suffix}"
    elif [ -n "$core_prefix" ]; then
        echo "$core_prefix"
    else
        echo "$suffix"
    fi
}

is_temurin_cn_build() {
    [ "$JDK_PROVIDER" = "temurin" ] && [ "$USE_CN_ENV" = "true" ]
}

refresh_tag_context() {
    STANDARD_TAG_PREFIX=$(build_tag_prefix)
    if is_temurin_cn_build; then
        JDK_TAG_PREFIX=$(build_tag_prefix "jdk" "cn")
        JDK_SHORT_TAG_PREFIX=$(build_short_tag_prefix "jdk-cn")
        JDK_BASE_IMAGE_VARIANT_SUFFIX="-jdk-cn"
    else
        JDK_TAG_PREFIX=$(build_tag_prefix "jdk")
        JDK_SHORT_TAG_PREFIX=$(build_short_tag_prefix "jdk")
        JDK_BASE_IMAGE_VARIANT_SUFFIX="-jdk"
    fi
    STANDARD_LAYER_TAG_PREFIX=$(build_tag_prefix "standard")
    STANDARD_CN_TAG_PREFIX=$(build_tag_prefix "standard_cn")
    CHINA_TAG_PREFIX=$(build_tag_prefix "cn")
    DEV_BASE_IMAGE_VARIANT_SUFFIX=""

    if [ "$USE_CN_ENV" = "true" ]; then
        TARGET_TAG_PREFIX="$CHINA_TAG_PREFIX"
        DEV_BASE_IMAGE_VARIANT_SUFFIX="-cn"
    else
        TARGET_TAG_PREFIX="$STANDARD_TAG_PREFIX"
    fi

    if [ "$BUILD_DEV" = "true" ]; then
        TARGET_TAG_PREFIX="${TARGET_TAG_PREFIX}-dev"
    fi

    IMAGE_TAG=$(build_image_tag "$TARGET_TAG_PREFIX" "$IMAGE_TAG_TIME")
}

TIME_FALLBACK="$(date +%Y%m%d%H%M%S)"

if ! validate_tag_time "$IMAGE_TAG_TIME"; then
    [ -n "$IMAGE_TAG_TIME" ] && echo "Warning: IMAGE_TAG_TIME '$IMAGE_TAG_TIME' is invalid, fallback to runtime timestamp."
    IMAGE_TAG_TIME="$TIME_FALLBACK"
fi

refresh_tag_context

build_compose_files() {
    if [ "$BUILD_DEV" = true ]; then
        echo "-f ${COMPOSE_DIR}/docker-compose.yml -f ${COMPOSE_DIR}/docker-compose.dev.yml -f ${COMPOSE_DIR}/docker-compose.kvm.yml"
    else
        echo "-f ${COMPOSE_DIR}/docker-compose.yml -f ${COMPOSE_DIR}/docker-compose.kvm.yml"
    fi
}

stop_compose_stack() {
    local compose_files

    compose_files=$(build_compose_files)

    if [ "$BUILD_DEV" = true ]; then
        echo "Stopping docker compose with DEV configuration..."
    else
        echo "Stopping standard docker compose..."
    fi

    export IMAGE_TAG="$IMAGE_TAG"
    export CONTAINER_HOME="$CONTAINER_HOME"
    docker compose $compose_files down
}


# If creating env, handle interactive mode
if [ "$CREATE_ENV" = true ]; then
    read -p "Enter JDK version (default: $OPENJDK_VERSION): " INPUT_VERSION
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

    if ! validate_tag_time "$IMAGE_TAG_TIME"; then
        IMAGE_TAG_TIME="$TIME_FALLBACK"
    fi
    refresh_tag_context

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
    local tag_prefix=$3
    local short_tag_prefix=${4:-}
    shift 4

    echo "--------------------------------------------------------"
    echo "Building: $name (Dockerfile: $df, Tag Prefix: '$tag_prefix')"

    add_tag_pair() {
        local tag_label=$1
        local tag_reason=${2:-"Primary timestamped tag"}
        local full_tag_name="${name}:$(build_image_tag "$tag_prefix" "$tag_label")"

        tags+=("-t" "$full_tag_name")
        ALL_BUILT_TAGS+=("${df}|${full_tag_name}|${tag_reason}")
    }

    add_short_tag_pair() {
        local tag_label=$1
        local tag_reason=${2:-"Short default tag alias"}
        local short_tag_name=""

        if [ -n "$short_tag_prefix" ]; then
            short_tag_name="${name}:$(build_image_tag "$short_tag_prefix" "$tag_label")"
        else
            short_tag_name="${name}:${tag_label}"
        fi

        tags+=("-t" "$short_tag_name")
        ALL_BUILT_TAGS+=("${df}|${short_tag_name}|${tag_reason}")
    }
    
    # Define common tags (primary timestamped tags)
    local tags=()
    add_tag_pair "$IMAGE_TAG_TIME" "Primary timestamped tag"
    
    # Add flavor-specific latest and snapshot tags
    if [ "$TAG_LATEST" = true ]; then
        add_tag_pair "latest" "Latest release tag"
    fi
    if [ "$TAG_SNAPSHOT" = true ]; then
        add_tag_pair "snapshot" "Snapshot development tag"
    fi

    if [ "$short_tag_prefix" != "$tag_prefix" ]; then
        add_short_tag_pair "$IMAGE_TAG_TIME" "Short default timestamp alias"
        if [ "$TAG_LATEST" = true ]; then
            add_short_tag_pair "latest" "Short default latest alias"
        fi
        if [ "$TAG_SNAPSHOT" = true ]; then
            add_short_tag_pair "snapshot" "Short default snapshot alias"
        fi
    fi

    local build_args=(
        --build-arg BASE_SYSTEM="$BASE_SYSTEM"
        --build-arg BASE_VERSION="$BASE_VERSION"
        --build-arg USERNAME="$CONTAINER_USER"
        --build-arg JDK_PROVIDER="$JDK_PROVIDER"
        --build-arg OPENJDK_VERSION="$OPENJDK_VERSION"
        --build-arg DESKTOP_TYPE="$DESKTOP_TYPE"
    )

    while [ "$#" -gt 0 ]; do
        build_args+=("$1")
        shift
    done

    # Execute the build
    if [ "$PUBLISH" = true ]; then
        docker buildx build \
            --platform linux/amd64,linux/arm64 \
            "${build_args[@]}" \
            "${tags[@]}" \
            --push \
            -f "$df" .
    elif [ "$EXECUTE_BUILD" = true ]; then
        docker build \
            "${build_args[@]}" \
            "${tags[@]}" \
            -f "$df" .
    fi
}

if [ "$PUBLISH" = true ] || [ "$EXECUTE_BUILD" = true ]; then
    BASE_JDK_DOCKERFILE="${DOCKERFILE_DIR}/openjdk.Dockerfile"
    if [ "$JDK_PROVIDER" = "temurin" ]; then
        if [ "$USE_CN_ENV" = "true" ]; then
            BASE_JDK_DOCKERFILE="${DOCKERFILE_DIR}/temurin_cn.Dockerfile"
        else
            BASE_JDK_DOCKERFILE="${DOCKERFILE_DIR}/temurin.Dockerfile"
        fi
    fi

    run_build "$BASE_JDK_DOCKERFILE" "${IMAGE_NAME}" "$JDK_TAG_PREFIX" "$JDK_SHORT_TAG_PREFIX"

    if [ "$BUILD_DEV" = true ]; then
        if [ "$USE_CN_ENV" = "true" ]; then
            run_build "${DOCKERFILE_DIR}/standard_cn.Dockerfile" "${IMAGE_NAME}" "$STANDARD_CN_TAG_PREFIX" "$(build_short_tag_prefix "standard_cn")" \
                --build-arg BASE_IMAGE_VARIANT_SUFFIX="$JDK_BASE_IMAGE_VARIANT_SUFFIX" \
                --build-arg BASE_IMAGE_SOURCE_LABEL="$IMAGE_TAG_TIME"
            run_build "${DOCKERFILE_DIR}/Dockerfile" "${IMAGE_NAME}" "$CHINA_TAG_PREFIX" "$(build_short_tag_prefix "cn")" \
                --build-arg BASE_IMAGE_VARIANT_SUFFIX="-standard_cn" \
                --build-arg BASE_IMAGE_SOURCE_LABEL="$IMAGE_TAG_TIME" \
                --build-arg USE_CN_ENV=true
            run_build "${DOCKERFILE_DIR}/dev.Dockerfile" "${IMAGE_NAME}" "${CHINA_TAG_PREFIX}-dev" "$(build_short_tag_prefix "cn-dev")" \
                --build-arg BASE_IMAGE_VARIANT_SUFFIX="-cn" \
                --build-arg BASE_IMAGE_SOURCE_LABEL="$IMAGE_TAG_TIME"
        else
            run_build "${DOCKERFILE_DIR}/standard.Dockerfile" "${IMAGE_NAME}" "$STANDARD_LAYER_TAG_PREFIX" "$(build_short_tag_prefix "standard")" \
                --build-arg BASE_IMAGE_VARIANT_SUFFIX="-jdk" \
                --build-arg BASE_IMAGE_SOURCE_LABEL="$IMAGE_TAG_TIME"
            run_build "${DOCKERFILE_DIR}/Dockerfile" "${IMAGE_NAME}" "$STANDARD_TAG_PREFIX" "$(build_short_tag_prefix "")" \
                --build-arg BASE_IMAGE_VARIANT_SUFFIX="-standard" \
                --build-arg BASE_IMAGE_SOURCE_LABEL="$IMAGE_TAG_TIME" \
                --build-arg USE_CN_ENV=false
            run_build "${DOCKERFILE_DIR}/dev.Dockerfile" "${IMAGE_NAME}" "${STANDARD_TAG_PREFIX}-dev" "$(build_short_tag_prefix "dev")" \
                --build-arg BASE_IMAGE_SOURCE_LABEL="$IMAGE_TAG_TIME"
        fi
    else
        if [ "$USE_CN_ENV" = "true" ]; then
            run_build "${DOCKERFILE_DIR}/standard_cn.Dockerfile" "${IMAGE_NAME}" "$STANDARD_CN_TAG_PREFIX" "$(build_short_tag_prefix "standard_cn")" \
                --build-arg BASE_IMAGE_VARIANT_SUFFIX="$JDK_BASE_IMAGE_VARIANT_SUFFIX" \
                --build-arg BASE_IMAGE_SOURCE_LABEL="$IMAGE_TAG_TIME"
            run_build "${DOCKERFILE_DIR}/Dockerfile" "${IMAGE_NAME}" "$CHINA_TAG_PREFIX" "$(build_short_tag_prefix "cn")" \
                --build-arg BASE_IMAGE_VARIANT_SUFFIX="-standard_cn" \
                --build-arg BASE_IMAGE_SOURCE_LABEL="$IMAGE_TAG_TIME" \
                --build-arg USE_CN_ENV=true
        else
            run_build "${DOCKERFILE_DIR}/standard.Dockerfile" "${IMAGE_NAME}" "$STANDARD_LAYER_TAG_PREFIX" "$(build_short_tag_prefix "standard")" \
                --build-arg BASE_IMAGE_VARIANT_SUFFIX="-jdk" \
                --build-arg BASE_IMAGE_SOURCE_LABEL="$IMAGE_TAG_TIME"
            run_build "${DOCKERFILE_DIR}/Dockerfile" "${IMAGE_NAME}" "$STANDARD_TAG_PREFIX" "$(build_short_tag_prefix "")" \
                --build-arg BASE_IMAGE_VARIANT_SUFFIX="-standard" \
                --build-arg BASE_IMAGE_SOURCE_LABEL="$IMAGE_TAG_TIME" \
                --build-arg USE_CN_ENV=false
        fi
    fi
    echo "Cleaning up dangling images..."
    docker image prune -f
fi

# Start container if requested
if [ "$START_CONTAINER" = true ]; then
    echo ""
    COMPOSE_FILES=$(build_compose_files)

    if [ "$BUILD_DEV" = true ]; then
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

if [ "$STOP_CONTAINER" = true ]; then
    echo ""
    stop_compose_stack
fi

# Print summary of all built tags grouped by Dockerfile at the very end
if [ ${#ALL_BUILT_TAGS[@]} -gt 0 ]; then
    echo ""
    echo "========================================================"
    echo "Final Summary of All Built Tags:"
    echo "========================================================"

    # Collect unique Dockerfiles in order
    declare -a unique_dfs=()
    for entry in "${ALL_BUILT_TAGS[@]}"; do
        df_name="${entry%%|*}"
        found=false
        for u in "${unique_dfs[@]}"; do
            [[ "$u" == "$df_name" ]] && found=true && break
        done
        if [ "$found" = false ]; then
            unique_dfs+=("$df_name")
        fi
    done

    # Print a table per Dockerfile
    for current_df in "${unique_dfs[@]}"; do
        # Calculate column widths for this group
        max_tag=3
        max_reason=6
        for entry in "${ALL_BUILT_TAGS[@]}"; do
            df_name="${entry%%|*}"
            [[ "$df_name" != "$current_df" ]] && continue
            tag_info="${entry#*|}"
            tag_name="${tag_info%%|*}"
            tag_reason="${tag_info#*|}"
            (( ${#tag_name} > max_tag )) && max_tag=${#tag_name}
            (( ${#tag_reason} > max_reason )) && max_reason=${#tag_reason}
        done

        echo ""
        echo "  [$current_df]"
        printf "  %-${max_tag}s | %-${max_reason}s\n" "Tag" "Reason"
        printf "  %-${max_tag}s-+-%-${max_reason}s\n" \
            "$(printf '%*s' "$max_tag" '' | tr ' ' '-')" \
            "$(printf '%*s' "$max_reason" '' | tr ' ' '-')"

        for entry in "${ALL_BUILT_TAGS[@]}"; do
            df_name="${entry%%|*}"
            [[ "$df_name" != "$current_df" ]] && continue
            tag_info="${entry#*|}"
            tag_name="${tag_info%%|*}"
            tag_reason="${tag_info#*|}"
            printf "  %-${max_tag}s | %-${max_reason}s\n" "$tag_name" "$tag_reason"
        done
    done

    echo ""
    echo "========================================================"
fi
