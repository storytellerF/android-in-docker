#!/bin/bash

echo "Current user: $(whoami)"

sudo chown -R $(whoami):$(whoami) /home/$(whoami)

# inject point

# Start supervisor
./bin/start-supervisord.sh