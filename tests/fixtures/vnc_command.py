#!/usr/bin/env python3
"""Headless VNC command adapters; optionally use a real encoder in Docker."""
import json
import os
from pathlib import Path
import subprocess
import sys

command = Path(sys.argv[0]).name
if command == "docker":
    if sys.argv[-3:] not in (["port", "android", "5901"], ["port", "main", "5901"]):
        raise SystemExit("Unexpected Docker command")
    print("127.0.0.1:15901")
elif command == "vncpasswd":
    data = sys.stdin.buffer.read()
    Path(os.environ["VNC_TEST_ENCODER_INPUT"]).write_bytes(data)
    image = os.environ.get("VNC_TEST_ENCODER_IMAGE")
    if image:
        subprocess.run([os.environ["VNC_TEST_REAL_DOCKER"], "run", "--rm", "--pull=never", "--network=none", "-i",
                        "--entrypoint", "/usr/bin/vncpasswd", image, "-f"], input=data, check=True)
    else:
        sys.stdout.buffer.write(data)
elif command == "vncviewer":
    if sys.argv[1:] == ["-h"]:
        print("-passwd file")
    else:
        Path(os.environ["VNC_TEST_VIEWER_ARGS"]).write_text(json.dumps(sys.argv[1:]))
else:
    raise SystemExit(f"Unexpected command: {command}")
