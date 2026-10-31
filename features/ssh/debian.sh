#!/usr/bin/env bash
set -euo pipefail
apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends openssh-server sudo && rm -rf /var/lib/apt/lists/*
