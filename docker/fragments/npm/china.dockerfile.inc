# Configure npm for root installations and the container user.
ARG USERNAME
ARG NPM_CONFIG_REGISTRY=https://registry.npmmirror.com

USER root
RUN NPM_CONFIG_REGISTRY="$NPM_CONFIG_REGISTRY" npm install -g nrm \
    && nrm use tencent \
    && node --version \
    && npm --version

USER $USERNAME
WORKDIR /home/$USERNAME
RUN nrm use tencent

# Subsequent installation fragments start as root.
USER root
