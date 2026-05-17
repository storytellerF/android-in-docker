ARG BASE_SYSTEM=alpine
ARG BASE_VERSION=latest
ARG DESKTOP_TYPE=xfce
ARG JDK_PROVIDER=openjdk
ARG OPENJDK_VERSION=21
ARG BASE_IMAGE_VARIANT_SUFFIX=-jdk
ARG BASE_IMAGE_SOURCE_LABEL=latest
FROM storytellerf/android-in-docker:${BASE_SYSTEM}-${BASE_VERSION}-${DESKTOP_TYPE}-${JDK_PROVIDER}${OPENJDK_VERSION}${BASE_IMAGE_VARIANT_SUFFIX}-${BASE_IMAGE_SOURCE_LABEL}

ARG USERNAME=alpine
ARG NPM_CONFIG_REGISTRY=https://registry.npmmirror.com

ENV NVM_DIR=/usr/local/nvm
ENV NVM_NODEJS_ORG_MIRROR=https://npmmirror.com/mirrors/node
ENV PATH=${NVM_DIR}/current/bin:${PATH}

USER root

RUN apk add --no-cache bash ca-certificates curl nodejs npm tar xz

RUN update-ca-certificates || true

RUN mkdir -p "$NVM_DIR" \
    && node_prefix="$(dirname "$(dirname "$(readlink -f "$(command -v node)")")")" \
    && ln -sfn "$node_prefix" "$NVM_DIR/current" \
    && printf 'export NVM_DIR=%s\n' "$NVM_DIR" > /etc/profile.d/nvm.sh \
    && printf '\nexport NVM_DIR=%s\n' "$NVM_DIR" >> /etc/profile

RUN NPM_CONFIG_REGISTRY="$NPM_CONFIG_REGISTRY" npm install -g nrm \
    && nrm use tencent \
    && node --version \
    && npm --version

RUN install -d -m 0755 /etc/docker \
    && printf '{\n  "registry-mirrors": [\n    "https://docker.1ms.run",\n    "https://docker.1panel.live",\n    "https://docker.m.daocloud.io"\n  ]\n}\n' > /etc/docker/daemon.json

ARG USER_UID=1000
ARG USER_GID=$USER_UID

USER $USERNAME
WORKDIR /home/$USERNAME
RUN nrm use tencent
