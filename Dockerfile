# Base Image
FROM debian:trixie

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
    fonts-noto \
    npm \
    sudo \
    openssh-server \
    && apt-get purge -y xfce4-power-manager xfce4-power-manager-data \
    && rm -rf /var/lib/apt/lists/*

RUN sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && locale-gen

# Setup a non-root user
ARG USERNAME=debian
ARG USER_UID=1000
ARG USER_GID=$USER_UID
ENV SUPERVISOR_USER=$USERNAME

# Setup Android SDK Environment
ENV ANDROID_HOME=/home/${USERNAME}/Android/Sdk
ENV PATH=$PATH:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/emulator

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

RUN mkdir -p /run/sshd

USER $USERNAME
WORKDIR /home/$USERNAME

# Setup Appium，全局安装会安装到/usr/local/lib/node_modules，需要sudo权限
RUN sudo npm install -g appium
# Setup appium driver and plugin，安装到~/.appium，不需要sudo权限
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
COPY --chown=${USER_UID}:${USER_GID} install-default-components.sh ./bin/install-default-components.sh
RUN chmod +x ./bin/install-default-components.sh
COPY --chown=${USER_UID}:${USER_GID} entrypoint.sh ./bin/entrypoint.sh
RUN chmod +x ./bin/entrypoint.sh

RUN mkdir -p ./log/supervisor \
    && mkdir -p ./run \
    && mkdir -p ./.vnc \
    && mkdir -p ./.android

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
# 22: SSH port
EXPOSE 6080 5901 5555 4723 22

# Command to run supervisor
ENTRYPOINT ["sh", "-c", "$HOME/bin/entrypoint.sh"]
