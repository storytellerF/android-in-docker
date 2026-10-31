ARG DESKTOP_BASE_IMAGE=storytellerf/desktop-in-docker:debian-trixie-xfce-latest
FROM ${DESKTOP_BASE_IMAGE}

USER root
COPY docker/scripts/ /tmp/image-scripts/
RUN bash /tmp/image-scripts/install-prerequisites.sh && rm -rf /tmp/image-scripts

ARG USERNAME=debian
ARG USER_UID=1000
ARG USER_GID=$USER_UID
ARG JDK_PROVIDER=openjdk
ARG OPENJDK_VERSION=21
ARG TOOL_SOURCE=default
ARG APPIUM_VERSION=3.3.0
ENV JAVA_HOME=/usr/local/java/current \
    NVM_DIR=/usr/local/nvm \
    PYTHON_PATH=/usr/local/python/current \
    PIPX_HOME=/usr/local/py-utils \
    PIPX_BIN_DIR=/usr/local/py-utils/bin
ENV ANDROID_HOME=/home/${USERNAME}/Android/Sdk \
    ANDROID_PROFILE_DIR=/home/${USERNAME}/android-profiles
ENV PATH=${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/emulator:${JAVA_HOME}/bin:${NVM_DIR}/current/bin:${PYTHON_PATH}/bin:${PIPX_BIN_DIR}:/usr/local/jupyter:${PATH}

# These are the same installers packaged as Features for external Dev Containers.
COPY features/ /tmp/features/
RUN _REMOTE_USER="$USERNAME" SOURCE="$TOOL_SOURCE" PROVIDER="$JDK_PROVIDER" VERSION="$OPENJDK_VERSION" bash /tmp/features/java/install.sh
RUN _REMOTE_USER="$USERNAME" SOURCE="$TOOL_SOURCE" bash /tmp/features/nodejs/install.sh
RUN _REMOTE_USER="$USERNAME" SOURCE="$TOOL_SOURCE" bash /tmp/features/python/install.sh
RUN _REMOTE_USER="$USERNAME" bash /tmp/features/ssh/install.sh
RUN _REMOTE_USER="$USERNAME" bash /tmp/features/kvm/install.sh
RUN _REMOTE_USER="$USERNAME" VERSION="$APPIUM_VERSION" bash /tmp/features/appium/install.sh
RUN rm -rf /tmp/features

# Provision Android directly from the pinned android-profile submodule.
COPY --chown=${USER_UID}:${USER_GID} external/android-profile/scripts/ /home/${USERNAME}/bin/
COPY --chown=${USER_UID}:${USER_GID} external/android-profile/profiles/ /home/${USERNAME}/android-profiles/
COPY --chown=${USER_UID}:${USER_GID} base-scripts/ /home/${USERNAME}/bin/
COPY --chown=${USER_UID}:${USER_GID} docker/config/supervisor/android.supervisord.conf /home/${USERNAME}/supervisor/conf.d/android.supervisord.conf
RUN chmod +x /home/${USERNAME}/bin/*.sh

USER ${USERNAME}
WORKDIR /home/${USERNAME}
EXPOSE 22 5555 4723
