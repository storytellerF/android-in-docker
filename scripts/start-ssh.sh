#!/bin/sh

if [ ! -f /usr/sbin/sshd ]; then
    echo "Error: sshd not found at /usr/sbin/sshd" >&2
    sleep infinity
fi

sudo /usr/sbin/sshd -D