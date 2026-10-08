#!/usr/bin/env bash
set -euo pipefail
pacman -Sy --noconfirm --needed python python-pip python-virtualenv &&     pacman -Scc --noconfirm
