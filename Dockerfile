ARG OPENJDK_VERSION=21
# This should be built from base.Dockerfile with `sh build-image.sh -B`
FROM storytellerf/android-in-docker-base:openjdk${OPENJDK_VERSION}

ARG USERNAME=debian
ARG USER_UID=1000
ARG USER_GID=$USER_UID

USER $USERNAME
WORKDIR /home/$USERNAME

# Copy Scripts
COPY --chown=${USER_UID}:${USER_GID} base-scripts ./bin
RUN chmod +x ./bin/*.sh

# Setup the startup script for the VNC server to launch the XFCE desktop
RUN mkdir -p .vnc && \
    echo "#!/bin/bash" > .vnc/xstartup && \
    echo "xrdb \$HOME/.Xresources" >> .vnc/xstartup && \
    echo "startxfce4 &" >> .vnc/xstartup && \
    chmod +x .vnc/xstartup

RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/home/${USERNAME}/.android-in-docker/.bash_history" \
    && echo "$SNIPPET" >> ~/.bashrc

RUN mkdir -p log/supervisor run

# Copy supervisor configuration
COPY --chown=${USER_UID}:${USER_GID} supervisord.conf ./supervisor/supervisord.conf

# 主要用于supervisor
ENV SUPERVISOR_USER=$USERNAME
# Setup Android SDK Environment
ENV ANDROID_HOME=/home/${USERNAME}/Android/Sdk
ENV PATH=$PATH:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/emulator

# Expose Ports:
# 6080: noVNC Web Interface
# 5901: VNC Server (for display :1)
# 5555: ADB port
# 4723: Appium port
EXPOSE 6080 5901 5555 4723

# Command to run supervisor
# ENTRYPOINT ["sh", "-c", "tail -f /dev/null"]
ENTRYPOINT ["sh", "-c", "$HOME/bin/entrypoint.sh"]
