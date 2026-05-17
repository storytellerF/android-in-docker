ARG BASE_SYSTEM=alpine
ARG BASE_VERSION=latest
ARG DESKTOP_TYPE=xfce
ARG JDK_PROVIDER=openjdk
ARG OPENJDK_VERSION=21
ARG BASE_IMAGE_VARIANT_SUFFIX=-jdk
ARG BASE_IMAGE_SOURCE_LABEL=latest
FROM storytellerf/android-in-docker:${BASE_SYSTEM}-${BASE_VERSION}-${DESKTOP_TYPE}-${JDK_PROVIDER}${OPENJDK_VERSION}${BASE_IMAGE_VARIANT_SUFFIX}-${BASE_IMAGE_SOURCE_LABEL}

ENV NVM_DIR=/usr/local/nvm
ENV PATH=${NVM_DIR}/current/bin:${PATH}

USER root

RUN apk add --no-cache bash ca-certificates curl nodejs npm tar xz

RUN update-ca-certificates || true

RUN mkdir -p "$NVM_DIR" \
    && node_prefix="$(dirname "$(dirname "$(readlink -f "$(command -v node)")")")" \
    && ln -sfn "$node_prefix" "$NVM_DIR/current" \
    && printf 'export NVM_DIR=%s\n' "$NVM_DIR" > /etc/profile.d/nvm.sh \
    && printf '\nexport NVM_DIR=%s\n' "$NVM_DIR" >> /etc/profile \
    && node --version \
    && npm --version
