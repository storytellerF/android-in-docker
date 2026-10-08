#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export PATH="$ROOT_DIR/tests/fake-bin:$PATH"
export FAKE_DOCKER_LOG=$(mktemp)
output=$(mktemp)
trap 'rm -f "$FAKE_DOCKER_LOG" "$output"' EXIT
cd "$ROOT_DIR"
for system in debian ubuntu fedora alpine; do
    for provider in openjdk temurin; do
        for mirror in --cn-mirror --no-cn-mirror; do
            ./scripts/build-image.sh -b "$mirror" -z UTC --jdk-provider "$provider" -s "$system" > "$output"
            python3 - "$system" "$provider" "$mirror" <<'PY'
import json, sys
from pathlib import Path
system, provider, mirror = sys.argv[1:]
p = Path('build/.devcontainer/devcontainer.json')
c = json.loads(p.read_text())
f = c['features']
assert f['./features/java']['provider'] == provider
assert f['./features/java']['source'] == ('china' if mirror == '--cn-mirror' else 'default')
assert './features/git' not in f
assert not Path('features/git').exists()
assert ' git' in (p.parent / c['build']['dockerfile']).read_text()
assert f['./features/nodejs']['source'] == ('china' if mirror == '--cn-mirror' else 'default')
assert ('./features/npm' in f) == (mirror == '--cn-mirror')
assert ('./features/vscode' in f) == (system in ['debian','ubuntu','fedora'])
assert f['./features/python']['source'] == ('china' if mirror == '--cn-mirror' else 'default')
assert './features/development-tools' not in f
assert './features/kvm' in f
assert './features/android' not in f
assert './features/appium' in f
assert not Path('docker/features/android').exists()
assert not (p.parent / 'features/appium/profile-scripts').exists()
template = (p.parent / c['build']['dockerfile']).read_text()
assert 'external/android-profile/scripts/' in template
assert 'external/android-profile/profiles/' in template
assert 'docker/config/supervisor/android.supervisord.conf' in template
assert not list(Path('docker').rglob('*.dockerfrag'))
PY
        done
    done
done
./scripts/build-image.sh -b -S --no-cn-mirror -z UTC > "$output"
rg -q 'ADB: adb connect localhost:15555' "$output"
./scripts/build-image.sh -T --no-cn-mirror -z UTC > "$output"
./scripts/build-image.sh -P --no-cn-mirror -z UTC > "$output"
python3 - "$FAKE_DOCKER_LOG" <<'PY'
import json, shlex, sys
built = set()
for line in open(sys.argv[1]):
    args = shlex.split(line)
    if args[:2] == ['devcontainer', 'build']:
        mode = 'publish' if '--push' in args else 'local'
        assert (mode, args[args.index('--test-base-image') + 1]) in built
        if mode == 'publish':
            assert args[args.index('--platform')+1] == 'linux/amd64,linux/arm64'
        continue
    if args[:2] == ['docker','build'] or args[:3] == ['docker','buildx','build']:
        mode = 'publish' if '--push' in args else 'local'
        for i, arg in enumerate(args):
            if arg == '-t': built.add((mode,args[i+1]))
assert any('docker-compose.kvm.yml up -d' in line for line in open(sys.argv[1]))
assert any('docker-compose.kvm.yml down' in line for line in open(sys.argv[1]))
PY
for unsupported in '--dev' '--system-image unused' '-b -s arch --no-cn-mirror' '-b -s ubuntu -v resolute --no-cn-mirror'; do
    if ./scripts/build-image.sh $unsupported > "$output" 2>&1; then
        echo "Unexpected success: $unsupported" >&2
        exit 1
    fi
done
echo 'Features configuration, desktop dependency order, publishing, and Compose smoke tests passed.'
