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
# Project-only provisioning is used locally but excluded from published Features.
shutil.copytree(root / 'docker/features/android', staged / 'android')
android = staged / 'android'
for name in ['scripts', 'profiles']:
    target = android / ('profile-scripts' if name == 'scripts' else name)
    shutil.rmtree(target)
    shutil.copytree(root / 'external/android-profile' / name, target)
for source in (root / 'base-scripts').glob('*.sh'):
    shutil.copy2(source, android / source.name)
shutil.copy2(root / 'scripts/start-ssh.sh', staged / 'ssh/start-ssh.sh')
for feature in ['android', 'ssh']:
    shutil.copy2(root / f'docker/config/supervisor/{feature}.supervisord.conf',
                 staged / feature / f'{feature}.supervisord.conf')
features = {}
def add(name, **options):
    features[f'./features/{name}'] = {'username': args.username, **options}
add('java', provider=args.provider, version=args.version, source='china' if args.china == 'true' else 'default')
add('nodejs', source='china' if args.china == 'true' else 'default')
if args.china == 'true':
    add('npm')
add('python', source='china' if args.china == 'true' else 'default')
add('ssh')
if args.system in ['debian', 'ubuntu', 'fedora']:
    add('vscode')
for name in ['kvm', 'android']:
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
