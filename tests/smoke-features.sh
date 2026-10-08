#!/usr/bin/env bash
# Real integration check for tool availability and KVM groups in a built image.
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DEVCONTAINER_CLI="${DEVCONTAINER_CLI:-devcontainer}"
context=$(mktemp -d)
image="android-in-docker-feature-test:$(date +%s)-$$"
cleanup() {
    docker image rm "$image" >/dev/null 2>&1 || true
    rm -rf "$context"
}
trap cleanup EXIT
mkdir -p "$context/.devcontainer/features"
for feature in java nodejs python kvm; do
    cp -R "$ROOT_DIR/features/$feature" "$context/.devcontainer/features/$feature"
done
cat > "$context/.devcontainer/Dockerfile" <<'EOF'
FROM debian:trixie
RUN apt-get update && apt-get install -y --no-install-recommends git && rm -rf /var/lib/apt/lists/*
RUN groupadd -g 992 existingkvm && useradd -m -s /bin/bash -u 1000 debian
USER debian
EOF
python3 - "$context" "${PYTHON_CHINA_MIRROR:-false}" <<'PY'
import json, sys
from pathlib import Path
features = {'./features/' + name: {} for name in ['java','nodejs','python','kvm']}
features['./features/python']['source'] = 'china' if sys.argv[2] == 'true' else 'default'
config = {'build': {'dockerfile': 'Dockerfile'}, 'remoteUser': 'debian', 'features': features,
          'overrideFeatureInstallOrder': list(features)}
(Path(sys.argv[1]) / '.devcontainer/devcontainer.json').write_text(json.dumps(config))
PY
"$DEVCONTAINER_CLI" build --workspace-folder "$context" --image-name "$image" --no-lockfile
docker run --rm --user debian --entrypoint /bin/bash "$image" -c '
    set -euo pipefail
    git --version
    java -version
    javac -version 2>&1 | grep -E "javac 21([.]|$)"
    test -x "$JAVA_HOME/bin/java"
    node --version
    npm --version
    . /usr/local/nvm/nvm.sh
    test "$(nvm --version)" = 0.40.3
    python3 --version
    pip3 --version
    virtualenv --version
    pip3 config --global get global.index-url
    venv=$(mktemp -d)
    python3 -m venv "$venv"
    "$venv/bin/python" -m pip --version
    rm -rf "$venv"
    test "$(getent group 992 | cut -d: -f1)" = existingkvm
    for gid in 992 993; do id -G | tr " " "\n" | grep -qx "$gid"; done
'
echo 'Real Feature installation, runtime paths, virtual environments, and KVM groups passed.'
