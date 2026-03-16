#!/bin/bash

echo "Current user: $(whoami)"

sudo chown -R ${USER_NAME}:${USER_NAME} /home/${USER_NAME}

# inject point

# Start supervisor
./bin/start-supervisord.sh