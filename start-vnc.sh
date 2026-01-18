#!/bin/bash
set -e

# Set VNC password if VNC_PASSWD environment variable is set
if [ -n "$VNC_PASSWD" ]; then
  echo "Setting VNC password."
  echo "$VNC_PASSWD" | vncpasswd -f > ~/.vnc/passwd
  chmod 600 ~/.vnc/passwd
else
  echo "VNC_PASSWD not set. VNC will start without a password."
fi

# Start VNC server and tail logs to keep the process alive
vncserver :1 -geometry 1280x800 -depth 24
tail -F ~/.vnc/*.log