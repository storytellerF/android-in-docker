#!/usr/bin/env bash
set -euo pipefail
dnf install -y python3 python3-pip python3-virtualenv &&     dnf clean all
