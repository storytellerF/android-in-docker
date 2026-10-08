#!/usr/bin/env python3
"""Stage publishable Features with references to the destination GHCR namespace."""
import argparse
import json
import re
import shutil
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--namespace', required=True)
parser.add_argument('--output', required=True, type=Path)
args = parser.parse_args()
namespace = args.namespace.lower()
if not re.fullmatch(r'[a-z0-9][a-z0-9_.-]*/[a-z0-9][a-z0-9_.-]*', namespace):
    parser.error('namespace must be owner/repository')
root = Path(__file__).resolve().parents[1]
source = root / 'features'
output = args.output.resolve()
if output.exists():
    parser.error('output must be a new staging directory')
features = sorted(p for p in source.iterdir() if (p / 'devcontainer-feature.json').is_file())
output.mkdir(parents=True)
for feature in features:
    target = output / feature.name
    shutil.copytree(feature, target)
    metadata_path = target / 'devcontainer-feature.json'
    metadata = json.loads(metadata_path.read_text())
    if metadata['id'] != feature.name or not (target / 'install.sh').is_file():
        parser.error(f'invalid Feature: {feature.name}')
    def reference(value):
        prefix = 'ghcr.io/storytellerf/android-in-docker/'
        if value.startswith(prefix):
            return f'ghcr.io/{namespace}/' + value[len(prefix):]
        if value.startswith('./features/'):
            return f'ghcr.io/{namespace}/' + value[len('./features/'):]
        return value
    metadata['installsAfter'] = [reference(value) for value in metadata.get('installsAfter', [])]
    metadata['documentationURL'] = f'https://github.com/{namespace}/tree/main/features/{feature.name}'
    metadata_path.write_text(json.dumps(metadata, indent=2) + '\n')
print(f'Staged {len(features)} Features for ghcr.io/{namespace}')
