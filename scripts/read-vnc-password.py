#!/usr/bin/env python3
"""Decode the VNC password with the same dotenv reader as the build entry point."""
import argparse
from pathlib import Path
import sys

from build_config import read_env


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("config", type=Path)
    args = parser.parse_args()
    values = read_env(args.config)
    print(values.get("VNC_PASSWD") or values.get("VNC_PASSWORD") or "password")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError) as error:
        print(f"Cannot read VNC configuration: {error}", file=sys.stderr)
        sys.exit(1)
