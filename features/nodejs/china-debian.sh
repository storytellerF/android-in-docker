#!/usr/bin/env bash
set -euo pipefail
NVM_VERSION="${NVM_VERSION:-v0.40.3}"

export NVM_DIR=/usr/local/nvm

export NVM_NODEJS_ORG_MIRROR=https://npmmirror.com/mirrors/node

export PATH=${NVM_DIR}/current/bin:${PATH}

set -eux; \
	apt-get update; \
	DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends --no-install-suggests \
		bash \
		ca-certificates \
		curl \
		tar \
		xz-utils; \
	rm -rf /var/lib/apt/lists/*

set -eux; \
	mkdir -p "$NVM_DIR"; \
	curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" -o /tmp/install-nvm.sh; \
	PROFILE=/dev/null NVM_DIR="$NVM_DIR" bash /tmp/install-nvm.sh; \
	bash -lc '. "$NVM_DIR/nvm.sh" && \
		nvm install node && \
		nvm alias default node && \
		node_version="$(nvm version default)" && \
		ln -sfn "$NVM_DIR/versions/node/$node_version" "$NVM_DIR/current"'; \
	printf 'export NVM_DIR=%s\n[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"\n' "$NVM_DIR" > /etc/profile.d/nvm.sh; \
	printf '\nexport NVM_DIR=%s\n[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"\n' "$NVM_DIR" >> /etc/bash.bashrc; \
	rm -f /tmp/install-nvm.sh;
