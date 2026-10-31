#!/usr/bin/env bash
set -euo pipefail
: "${JDK_HOME_FILE:?The Java entry point must supply JDK_HOME_FILE}"
home=
while IFS= read -r candidate; do
    [ -z "$home" ] || continue
    candidate="/${candidate#/}"
    case "$candidate" in
        /bin/*|/usr/bin/*|/usr/local/bin/*) continue ;;
        */bin/javac) ;;
        *) continue ;;
    esac
    [ -x "$candidate" ] || continue
    candidate_home=$(dirname "$(dirname "$(readlink -f "$candidate")")")
    [ -x "$candidate_home/bin/java" ] || continue
    home="$candidate_home"
done
if [ -n "$home" ]; then
    printf '%s\n' "$home" > "$JDK_HOME_FILE"
    exit 0
fi
echo "No package-owned JDK home found" >&2
exit 1
