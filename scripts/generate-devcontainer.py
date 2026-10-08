#!/usr/bin/env python3
"""Generate a local Features build configuration and refresh upstream payloads."""
import argparse
import json
import shutil
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--system', required=True)
parser.add_argument('--username', required=True)
parser.add_argument('--provider', required=True)
parser.add_argument('--version', required=True)
parser.add_argument('--china', choices=['true', 'false'], required=True)
parser.add_argument('--desktop-image', required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
output = root / 'build/.devcontainer'
output.mkdir(parents=True, exist_ok=True)
# Stage Features rather than modifying the tracked source while building.
staged = output / 'features'
if staged.exists():
    shutil.rmtree(staged)
shutil.copytree(root / 'features', staged)
shutil.copy2(root / 'scripts/start-ssh.sh', staged / 'ssh/start-ssh.sh')
shutil.copy2(root / 'docker/config/supervisor/ssh.supervisord.conf', staged / 'ssh/ssh.supervisord.conf')
features = {}
def add(name, **options):
    features[f'./features/{name}'] = options
add('java', provider=args.provider, version=args.version, source='china' if args.china == 'true' else 'default')
add('nodejs', source='china' if args.china == 'true' else 'default')
if args.china == 'true':
    add('npm')
add('python', source='china' if args.china == 'true' else 'default')
add('ssh')
if args.system in ['debian', 'ubuntu', 'fedora']:
    add('vscode')
for name in ['kvm', 'appium']:
    add(name)
system = 'debian' if args.system == 'ubuntu' else args.system
config = {
    'name': 'Android development image',
    'build': {
        'dockerfile': f'../../docker/dockerfiles/default/{system}.Dockerfile',
        'context': '../..',
        'args': {'DESKTOP_BASE_IMAGE': args.desktop_image, 'USERNAME': args.username},
    },
    'remoteUser': args.username,
    'features': features,
    'overrideFeatureInstallOrder': list(features),
}
(output / 'devcontainer.json').write_text(json.dumps(config, indent=2) + '\n')
print(output / 'devcontainer.json')
