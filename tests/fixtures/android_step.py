#!/usr/bin/env python3
"""Executable stand-in for the SDK/AVD scripts called by start-android.sh."""
import os
from pathlib import Path
import sys

name = Path(sys.argv[0]).stem
with open(os.environ["STARTUP_LOG"], "a") as log:
    log.write(f"{name}:{' '.join(sys.argv[1:])}\n")
if name == "install-sdk" and os.environ.get("FAIL_SDK") == "true":
    sys.exit(7)
