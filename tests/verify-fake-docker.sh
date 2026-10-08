#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
FAKE_BIN_DIR="$ROOT_DIR/tests/fake-bin"
export PATH="$FAKE_BIN_DIR:$PATH"
export FAKE_DOCKER_LOG="${TMPDIR:-/tmp}/android-in-docker-fake-docker.$$.log"

cd "$ROOT_DIR"
: > "$FAKE_DOCKER_LOG"
standard_out=$(mktemp "${TMPDIR:-/tmp}/android-in-docker-fake-build.XXXXXX.out")
start_out=$(mktemp "${TMPDIR:-/tmp}/android-in-docker-fake-start.XXXXXX.out")
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

echo "== fake docker smoke: unified build =="
./scripts/build-image.sh -b --no-cn-mirror -z UTC --no-snapshot --jdk-provider openjdk -j 21 -s debian -v trixie -d xfce >"$standard_out"
assert_file_exists "build/android/debian.Dockerfile"
assert_contains "$FAKE_DOCKER_LOG" "docker build "
assert_contains "$FAKE_DOCKER_LOG" "-f build/android/debian.Dockerfile"
assert_contains "$FAKE_DOCKER_LOG" "android-in-docker:debian-trixie-xfce-openjdk21-"
assert_contains "$FAKE_DOCKER_LOG" "docker image prune -f"

echo "== fake docker smoke: cn build and start =="
./scripts/build-image.sh -b -S --cn-mirror -z Asia/Shanghai --latest --jdk-provider openjdk -j 21 -s debian -v trixie -d xfce >"$start_out"
assert_file_exists "build/android/debian_cn.Dockerfile"
assert_contains "$FAKE_DOCKER_LOG" "-f build/android/debian_cn.Dockerfile"
assert_contains "build/android/debian_cn.Dockerfile" "# Source: docker/fragments/ssh/configure.dockerfrag"
assert_contains "$start_out" "SSH: ssh -p 10022"
assert_contains "$FAKE_DOCKER_LOG" "docker compose -f docker/compose/docker-compose.yml up -d --build"
assert_contains "$FAKE_DOCKER_LOG" "docker compose -f docker/compose/docker-compose.yml port android 6080"
assert_contains "$start_out" "Web VNC: http://localhost:16080/vnc.html"

echo "== fake docker smoke: compose stop =="
./scripts/build-image.sh -T --no-cn-mirror -z UTC --jdk-provider openjdk -j 21 -s debian -v trixie -d xfce >"$stop_out"
assert_contains "$FAKE_DOCKER_LOG" "docker compose -f docker/compose/docker-compose.yml down"

echo "== fake docker smoke: all base systems without removed dependencies =="
for system in debian ubuntu fedora alpine; do
    for provider in openjdk temurin; do
        for mirror in --cn-mirror --no-cn-mirror; do
            ./scripts/build-image.sh -b "$mirror" -z UTC --jdk-provider "$provider" -s "$system" >"$standard_out"
            generated="build/android/${system}.Dockerfile"
            [ "$mirror" != --cn-mirror ] || generated="build/android/${system}_cn.Dockerfile"
            assert_file_exists "$generated"
            if grep -Eq 'external/docker/|dockerd|/usr/local/bin/dind|EXPOSE.*(2375|2376)' "$generated"; then
                echo "Removed runtime dependency remains in $generated" >&2
                exit 1
            fi
            assert_contains "$generated" "install-appium.sh"
            assert_contains "$generated" "external/android-profile/scripts/"
            assert_contains "$generated" "# Source: docker/fragments/android-sdk/configure.dockerfrag"
            assert_contains "$generated" "ENV ANDROID_HOME="
            assert_contains "$generated" "# Source: docker/fragments/kvm/permissions.dockerfrag"
            assert_contains "$generated" "ARG KVM_GID=109"
            assert_contains "$generated" "# Source: docker/fragments/development-tools/"
            assert_contains "$generated" "# Source: docker/fragments/ssh/configure.dockerfrag"
            assert_contains "$generated" "EXPOSE 22"
            if [ "$system" = debian ] || [ "$system" = ubuntu ] || [ "$system" = fedora ]; then
                assert_contains "$generated" "# Source: docker/fragments/vscode/"
            fi
        done
    done
done

if ./scripts/build-image.sh --system-image unused >"$standard_out" 2>&1; then
    echo "Removed system-image option is still accepted" >&2
    exit 1
fi
assert_contains "$standard_out" "Unknown parameter passed: --system-image"

if ./scripts/build-image.sh --dev >"$standard_out" 2>&1; then
    echo "Removed dev mode is still accepted" >&2
    exit 1
fi
assert_contains "$standard_out" "Unknown parameter passed: --dev"

echo "== fake docker smoke: publish dependency chain =="
./scripts/build-image.sh -P --no-cn-mirror -z UTC -s debian -v trixie >"$standard_out"

python3 - "$FAKE_DOCKER_LOG" <<'PYTEST'
import shlex, sys
built = set()
for line in open(sys.argv[1]):
    args = shlex.split(line)
    if args[:2] != ['docker', 'build'] and args[:3] != ['docker', 'buildx', 'build']:
        continue
    mode = 'publish' if '--push' in args else 'local'
    for arg in args:
        for key in ('BASE_IMAGE=', 'DESKTOP_BASE_IMAGE='):
            if arg.startswith(key):
                ref = arg[len(key):]
                assert (mode, ref) in built, f'{ref} was not built first in {mode} mode'
    for i, arg in enumerate(args):
        if arg == '-t':
            built.add((mode, args[i + 1]))
assert any(mode == 'publish' and 'android-in-docker:' in ref for mode, ref in built)
print('Desktop → unified Android image references and build order passed.')
PYTEST

: > "$FAKE_DOCKER_LOG"
if ./scripts/build-image.sh -b -s arch --no-cn-mirror >"$standard_out" 2>&1; then
    echo "Unsupported desktop build unexpectedly succeeded" >&2
    exit 1
fi
assert_contains "$standard_out" "does not support --system arch"
if [ -s "$FAKE_DOCKER_LOG" ]; then
    echo "Dependent image built after desktop validation failed" >&2
    exit 1
fi

echo "Fake docker log: $FAKE_DOCKER_LOG"
echo "All fake docker tests passed."
