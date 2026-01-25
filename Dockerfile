# Base Image
FROM ubuntu:25.10

ARG OPENJDK_VERSION
# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install Dependencies: VNC, Desktop, Supervisor, Java, KVM, and other tools
RUN apt-get update && apt-get install -y \
    dbus-x11 \
    supervisor \
    tightvncserver \
    xfce4 \
    xfce4-goodies \
    novnc \
    websockify \
    net-tools \
    openjdk-${OPENJDK_VERSION}-jdk \
    wget \
    unzip \
    qemu-kvm \
    elinks \
    locales \
    fonts-wqy-microhei \
    fonts-wqy-zenhei \
    npm \
    sudo \
    && apt-get purge -y xfce4-power-manager xfce4-power-manager-data \
    && rm -rf /var/lib/apt/lists/*

# Setup Android SDK Environment
ENV ANDROID_SDK_ROOT=/opt/android/sdk
ENV PATH=$PATH:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools:${ANDROID_SDK_ROOT}/emulator

# Setup Appium
RUN npm install -g appium

# Setup a non-root user
ARG USERNAME=ubuntu
ARG USER_UID=1000
ARG USER_GID=$USER_UID
ARG KVM_GID

RUN echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

RUN usermod -aG ${KVM_GID} ubuntu

USER $USERNAME
WORKDIR /home/$USERNAME

# Setup appium driver and plugin
RUN appium driver install uiautomator2
RUN appium plugin install storage
RUN appium plugin install inspector

# Copy Scripts
COPY --chown=${USER_UID}:${USER_GID} install-sdk.sh ./bin/install-sdk.sh
RUN chmod +x ./bin/install-sdk.sh
COPY --chown=${USER_UID}:${USER_GID} start-android.sh ./bin/start-android.sh
RUN chmod +x ./bin/start-android.sh
COPY --chown=${USER_UID}:${USER_GID} start-vnc.sh ./bin/start-vnc.sh
RUN chmod +x ./bin/start-vnc.sh
COPY --chown=${USER_UID}:${USER_GID} start-appium.sh ./bin/start-appium.sh
RUN chmod +x ./bin/start-appium.sh
COPY --chown=${USER_UID}:${USER_GID} sdkmanager-as-root.sh ./bin/sdkmanager-as-root.sh
RUN chmod +x ./bin/sdkmanager-as-root.sh
COPY --chown=${USER_UID}:${USER_GID} install-default-components.sh ./bin/install-default-components.sh
RUN chmod +x ./bin/install-default-components.sh

RUN mkdir -p ./log/supervisor \
    && mkdir -p ./run \
    && mkdir -p ./.vnc

# Setup the startup script for the VNC server to launch the XFCE desktop
RUN echo "#!/bin/bash" > ./.vnc/xstartup && \
    echo "xrdb \$HOME/.Xresources" >> ./.vnc/xstartup && \
    echo "startxfce4 &" >> ./.vnc/xstartup && \
    chmod +x ./.vnc/xstartup

# Copy supervisor configuration
COPY supervisord.conf /etc/supervisor/supervisord.conf

# Expose Ports:
# 6080: noVNC Web Interface
# 5901: VNC Server (for display :1)
# 5555: ADB port
# 4723: Appium port
EXPOSE 6080 5901 5555 4723

# Command to run supervisor
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
