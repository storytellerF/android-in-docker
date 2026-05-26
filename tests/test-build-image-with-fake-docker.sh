#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
FAKE_BIN_DIR="$ROOT_DIR/tests/fake-bin"
export PATH="$FAKE_BIN_DIR:$PATH"
export FAKE_DOCKER_LOG="${TMPDIR:-/tmp}/android-in-docker-fake-docker.$$.log"

cd "$ROOT_DIR"
: > "$FAKE_DOCKER_LOG"
standard_out=$(mktemp "${TMPDIR:-/tmp}/android-in-docker-fake-build.XXXXXX.out")
dev_start_out=$(mktemp "${TMPDIR:-/tmp}/android-in-docker-fake-dev-start.XXXXXX.out")
stop_out=$(mktemp "${TMPDIR:-/tmp}/android-in-docker-fake-stop.XXXXXX.out")

assert_contains() {
    local file=$1
    local expected=$2
    if ! grep -Fq -- "$expected" "$file"; then
        echo "Expected to find in $file:" >&2
        echo "  $expected" >&2
        echo "" >&2
        echo "Actual contents:" >&2
        sed -n '1,200p' "$file" >&2
        exit 1
    fi
}

assert_file_exists() {
    local file=$1
    if [ ! -f "$file" ]; then
        echo "Expected file to exist: $file" >&2
        exit 1
    fi
}

echo "== fake docker smoke: standard build =="
./scripts/build-image.sh -b --no-cn-mirror -z UTC --no-snapshot --jdk-provider openjdk -j 21 -s debian -v trixie -d xfce >"$standard_out"
assert_file_exists "build/android/debian.Dockerfile"
assert_contains "$FAKE_DOCKER_LOG" "docker build "
assert_contains "$FAKE_DOCKER_LOG" "-f build/android/debian.Dockerfile"
assert_contains "$FAKE_DOCKER_LOG" "android-in-docker:debian-trixie-xfce-openjdk21-"
assert_contains "$FAKE_DOCKER_LOG" "docker image prune -f"

echo "== fake docker smoke: cn dev build and start =="
./scripts/build-image.sh -b -D -S --cn-mirror -z Asia/Shanghai --latest --jdk-provider openjdk -j 21 -s debian -v trixie -d xfce >"$dev_start_out"
assert_file_exists "build/android/debian_cn.Dockerfile"
assert_contains "$FAKE_DOCKER_LOG" "-f build/android/debian_cn.Dockerfile"
assert_contains "$FAKE_DOCKER_LOG" "-f docker/dockerfiles/dev/debian.Dockerfile"
assert_contains "$FAKE_DOCKER_LOG" "docker compose -f docker/compose/docker-compose.yml -f docker/compose/docker-compose.dev.yml -f docker/compose/docker-compose.kvm.yml -f docker/compose/docker-compose.privileged.yml up -d --build"
assert_contains "$FAKE_DOCKER_LOG" "docker compose -f docker/compose/docker-compose.yml -f docker/compose/docker-compose.dev.yml -f docker/compose/docker-compose.kvm.yml -f docker/compose/docker-compose.privileged.yml port android 6080"
assert_contains "$dev_start_out" "Web VNC: http://localhost:16080/vnc.html"

echo "== fake docker smoke: compose stop =="
./scripts/build-image.sh -T --no-cn-mirror -z UTC --jdk-provider openjdk -j 21 -s debian -v trixie -d xfce >"$stop_out"
assert_contains "$FAKE_DOCKER_LOG" "docker compose -f docker/compose/docker-compose.yml -f docker/compose/docker-compose.kvm.yml -f docker/compose/docker-compose.privileged.yml down"

echo "Fake docker log: $FAKE_DOCKER_LOG"
echo "All fake docker tests passed."
