FROM debian:trixie
RUN apt-get update && apt-get install -y --no-install-recommends node-corepack && rm -rf /var/lib/apt/lists/*
RUN useradd -m -s /bin/bash -u 1000 debian
ENV NVM_DIR=/usr/local/nvm
ENV PATH=${NVM_DIR}/current/bin:${PATH}
COPY features/_common/ /tmp/_common/
COPY features/nodejs/ /tmp/nodejs/
RUN _REMOTE_USER=debian SOURCE=default bash /tmp/nodejs/install.sh && rm -rf /tmp/nodejs
USER debian
