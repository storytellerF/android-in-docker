#!/usr/bin/env bash
set -euo pipefail
dnf install -y openssh-server sudo && dnf clean all
