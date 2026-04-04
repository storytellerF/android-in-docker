ARG BASE_SYSTEM=debian
ARG BASE_VERSION=trixie
ARG DESKTOP_TYPE=xfce
FROM storytellerf/desktop-in-docker:${BASE_SYSTEM}-${BASE_VERSION}-${DESKTOP_TYPE}-latest

ARG OPENJDK_VERSION=21

USER root

# Install Dependencies: Java, KVM, and other tools
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends --no-install-suggests \
    openjdk-${OPENJDK_VERSION}-jdk \
    qemu-kvm \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Setup a non-root user
ARG USERNAME=debian

USER $USERNAME
WORKDIR /home/$USERNAME

ARG TIMEZONE=Asia/Shanghai
COPY --chown=$USERNAME:$USERNAME base-scripts/install-appium.sh ./base-scripts/install-appium.sh
RUN chmod +x ./base-scripts/install-appium.sh && ./base-scripts/install-appium.sh $TIMEZONE
