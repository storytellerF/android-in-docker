# Base Image
FROM storytellerf/desktop-in-docker:trixie-xfce-latest

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

# Setup Appium，全局安装会安装到/usr/local/lib/node_modules，需要sudo权限
RUN sudo npm install -g appium
# Setup appium driver and plugin，安装到~/.appium，不需要sudo权限
RUN appium driver install uiautomator2
RUN appium plugin install storage
RUN appium plugin install inspector
