#!/usr/bin/env bash
set -euo pipefail
pacman -Sy --noconfirm --needed openssh sudo && pacman -Scc --noconfirm
