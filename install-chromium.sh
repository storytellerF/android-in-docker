#!/bin/bash
set -e

# Clone the repository to the user's home directory
CHROMIUM_DIR="$HOME/chromium-latest-linux"

if [ ! -d "$CHROMIUM_DIR" ]; then
    git clone https://github.com/scheib/chromium-latest-linux.git "$CHROMIUM_DIR"
fi

cd "$CHROMIUM_DIR"
./update.sh

# Link the chromium executable to /usr/local/bin/chromium
sudo ln -sf "$CHROMIUM_DIR/latest/chrome" /usr/local/bin/chromium
