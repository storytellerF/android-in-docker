#!/bin/bash

# Try to find the docker-compose file
COMPOSE_FILE=""
if [ -f ".devcontainer/docker-compose.yml" ]; then
    COMPOSE_FILE=".devcontainer/docker-compose.yml"
elif [ -f "docker-compose.yml" ]; then
    COMPOSE_FILE="docker-compose.yml"
elif [ -f "docker-compose.dev.yml" ]; then
    COMPOSE_FILE="docker-compose.dev.yml"
fi

if [ -z "$COMPOSE_FILE" ]; then
    echo "Error: No docker-compose configuration file found."
    exit 1
fi

# Determine service name based on which compose file is used
SERVICE_NAME="android"
if [ "$COMPOSE_FILE" == ".devcontainer/docker-compose.yml" ] || [ "$COMPOSE_FILE" == "devcontainer/docker-compose.yml" ]; then
    SERVICE_NAME="main"
fi

# Find the host port mapping for container:5901 (VNC direct connection) using docker compose
echo "Detecting VNC port via docker compose..."
VNC_PORT_MAPPING=$(docker compose -f "$COMPOSE_FILE" port "$SERVICE_NAME" 5901 2>/dev/null)
if [ -n "$VNC_PORT_MAPPING" ]; then
    VNC_PORT=${VNC_PORT_MAPPING##*:}
else
    echo "Warning: No running container found via docker compose for service $SERVICE_NAME. Falling back to configuration file check."
    # Fallback to static grep if container is not running. 
    # Tries to match "host_port:5901" or just "5901"
    VNC_PORT=$(sed -nE 's/.*-.*"?([0-9]+):5901"?/\1/p' "$COMPOSE_FILE" | head -n 1)
    if [ -z "$VNC_PORT" ] && grep -qE "\"?5901\"?" "$COMPOSE_FILE"; then
        echo "Note: Dynamic port mapping detected for 5901. You must start the container to determine the host port."
    fi
fi

if [ -z "$VNC_PORT" ]; then
    echo "Warning: Could not determine VNC host port mapping (container:5901). Falling back to default 5901."
    VNC_PORT=5901
fi

echo "Detected host port: $VNC_PORT"

# 2. Get password from .devcontainer/.env or .env and save to passwd file
ENV_FILE=""
if [ -f ".devcontainer/.env" ]; then
    ENV_FILE=".devcontainer/.env"
elif [ -f ".env" ]; then
    ENV_FILE=".env"
fi

VNC_PASSWD="password"
if [ -n "$ENV_FILE" ]; then
    # Extracts VNC_PASSWD or VNC_PASSWORD from env file
    VNC_PASSWD_FROM_ENV=$(grep -E "^VNC_PASS(WD|WORD)=" "$ENV_FILE" | cut -d= -f2- | tr -d '"' | tr -d "'")
    if [ -n "$VNC_PASSWD_FROM_ENV" ]; then
        VNC_PASSWD="$VNC_PASSWD_FROM_ENV"
    fi
fi

# Create password file for vncviewer
PASSWD_FILE=".devcontainer/tmp/passwd"
# If not using .devcontainer, fallback to a local tmp directory if desired
if [ ! -d ".devcontainer" ] && [ -d "devcontainer" ]; then
    PASSWD_FILE="devcontainer/tmp/passwd"
elif [ ! -d ".devcontainer" ]; then
    PASSWD_FILE=".tmp/passwd"
fi

mkdir -p "$(dirname "$PASSWD_FILE")"

echo "Creating password file at $PASSWD_FILE..."
# vncpasswd -f generates the obfuscated password file.
if command -v vncpasswd &> /dev/null; then
    echo "$VNC_PASSWD" | vncpasswd -f > "$PASSWD_FILE"
    chmod 600 "$PASSWD_FILE"
else
    echo "$VNC_PASSWD" > "$PASSWD_FILE"
    chmod 600 "$PASSWD_FILE"
    echo "Warning: vncpasswd not found. Saving as plain text password file."
fi

# Check if vncviewer exists
if ! command -v vncviewer &> /dev/null; then
    echo "Error: vncviewer is not installed or not in your PATH."
    echo "Please install it (e.g., sudo apt install tigervnc-viewer or xtightvncviewer)"
    exit 1
fi

echo "Launching vncviewer localhost:$VNC_PORT ..."
# Detect viewer type to choose correct argument
if vncviewer -h 2>&1 | grep -q "PasswordFile"; then
    # RealVNC uses -PasswordFile
    vncviewer "localhost:$VNC_PORT" -PasswordFile="$PASSWD_FILE"
elif vncviewer -h 2>&1 | grep -q "\-passwd"; then
    # TigerVNC/TightVNC use -passwd
    vncviewer "localhost:$VNC_PORT" -passwd "$PASSWD_FILE"
else
    # Fallback to general execution
    vncviewer "localhost:$VNC_PORT"
fi

