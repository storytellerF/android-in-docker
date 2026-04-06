ARG BASE_SYSTEM=debian
ARG BASE_VERSION=trixie
ARG DESKTOP_TYPE=xfce
ARG OPENJDK_VERSION=21
ARG BASE_IMAGE_VARIANT_SUFFIX=-jdk
ARG BASE_IMAGE_SOURCE_LABEL=latest
FROM storytellerf/android-in-docker:${BASE_SYSTEM}-${BASE_VERSION}-${DESKTOP_TYPE}-openjdk${OPENJDK_VERSION}${BASE_IMAGE_VARIANT_SUFFIX}-${BASE_IMAGE_SOURCE_LABEL}

ARG USERNAME=debian
ARG NVM_VERSION=v0.40.3

ENV NVM_DIR=/usr/local/nvm
ENV NVM_NODEJS_ORG_MIRROR=https://npmmirror.com/mirrors/node
ARG NPM_CONFIG_REGISTRY=https://registry.npmmirror.com
ENV PATH=${NVM_DIR}/current/bin:${PATH}

USER root

RUN apt-get update && \
	DEBIAN_FRONTEND=noninteractive apt-get install -y fcitx fcitx-googlepinyin && \
	rm -rf /var/lib/apt/lists/*;

RUN set -eux; \
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

RUN NPM_CONFIG_REGISTRY="$NPM_CONFIG_REGISTRY" npm install -g nrm && \
		nrm use tencent && \
		node --version && \
		npm --version;

RUN install -d -m 0755 /etc/docker && \
	printf '{\n  "registry-mirrors": [\n    "https://docker.1ms.run",\n    "https://docker.1panel.live",\n    "https://docker.m.daocloud.io"\n  ]\n}\n' > /etc/docker/daemon.json

ARG USER_UID=1000
ARG USER_GID=$USER_UID

USER $USERNAME
WORKDIR /home/$USERNAME
RUN nrm use tencent

COPY --chown=${USER_UID}:${USER_GID} fcitx/config .config/fcitx/config
COPY --chown=${USER_UID}:${USER_GID} fcitx/profile .config/fcitx/profile
COPY --chown=${USER_UID}:${USER_GID} fcitx.supervisord.conf ./supervisor/conf.d/fcitx.supervisord.conf