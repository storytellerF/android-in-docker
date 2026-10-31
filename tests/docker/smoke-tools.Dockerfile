FROM debian:trixie
RUN apt-get update && apt-get install -y --no-install-recommends git && rm -rf /var/lib/apt/lists/*
RUN groupadd -g 992 existingkvm && useradd -m -s /bin/bash -u 1000 debian
ENV JAVA_HOME=/usr/local/java/current NVM_DIR=/usr/local/nvm \
    PYTHON_PATH=/usr/local/python/current PIPX_HOME=/usr/local/py-utils PIPX_BIN_DIR=/usr/local/py-utils/bin
ENV PATH=${JAVA_HOME}/bin:${NVM_DIR}/current/bin:${PYTHON_PATH}/bin:${PIPX_BIN_DIR}:${PATH}
ARG PYTHON_SOURCE=default
COPY features/ /tmp/features/
RUN _REMOTE_USER=debian SOURCE=default PROVIDER=openjdk VERSION=21 bash /tmp/features/java/install.sh
ARG NODE_SOURCE=default
RUN _REMOTE_USER=debian SOURCE="$NODE_SOURCE" bash /tmp/features/nodejs/install.sh
RUN _REMOTE_USER=debian SOURCE="$PYTHON_SOURCE" bash /tmp/features/python/install.sh
RUN _REMOTE_USER=debian bash /tmp/features/kvm/install.sh && rm -rf /tmp/features
USER debian
