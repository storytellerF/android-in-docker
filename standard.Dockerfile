ARG BASE_SYSTEM=debian
ARG BASE_VERSION=trixie
ARG DESKTOP_TYPE=xfce
ARG OPENJDK_VERSION=21
ARG BASE_IMAGE_VARIANT_SUFFIX=-jdk
ARG BASE_IMAGE_SOURCE_LABEL=latest
FROM storytellerf/android-in-docker:${BASE_SYSTEM}-${BASE_VERSION}-${DESKTOP_TYPE}-openjdk${OPENJDK_VERSION}${BASE_IMAGE_VARIANT_SUFFIX}-${BASE_IMAGE_SOURCE_LABEL}

ARG NVM_VERSION=v0.40.3

ENV NVM_DIR=/usr/local/nvm
ENV PATH=${NVM_DIR}/current/bin:${PATH}

USER root

RUN set -eux; \
    mkdir -p "$NVM_DIR"; \
    curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" -o /tmp/install-nvm.sh; \
    PROFILE=/dev/null NVM_DIR="$NVM_DIR" bash /tmp/install-nvm.sh; \
    bash -lc '. "$NVM_DIR/nvm.sh" && \
        nvm install node && \
        nvm alias default node && \
        node_version="$(nvm version default)" && \
        ln -sfn "$NVM_DIR/versions/node/$node_version" "$NVM_DIR/current" && \
        node --version && npm --version'; \
    printf 'export NVM_DIR=%s\n[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"\n' "$NVM_DIR" > /etc/profile.d/nvm.sh; \
    printf '\nexport NVM_DIR=%s\n[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"\n' "$NVM_DIR" >> /etc/bash.bashrc; \
    rm -f /tmp/install-nvm.sh