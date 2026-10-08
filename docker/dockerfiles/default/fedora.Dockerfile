ARG BASE_SYSTEM=fedora
ARG BASE_VERSION=44
ARG DESKTOP_TYPE=xfce
ARG JDK_PROVIDER=openjdk
ARG OPENJDK_VERSION=21
ARG DESKTOP_IMAGE_REGION_SUFFIX=
ARG DESKTOP_IMAGE_LABEL=latest
ARG DESKTOP_BASE_IMAGE=storytellerf/desktop-in-docker:${BASE_SYSTEM}-${BASE_VERSION}-${DESKTOP_TYPE}${DESKTOP_IMAGE_REGION_SUFFIX}-${DESKTOP_IMAGE_LABEL}
FROM ${DESKTOP_BASE_IMAGE}

USER root
# Install project image prerequisites for Git and Android provisioning.
RUN dnf install -y git bash ca-certificates wget unzip sudo && dnf clean all

# Install the desktop editor as part of the project image.
COPY docker/scripts/vscode/fedora.sh /tmp/install-vscode.sh
RUN bash /tmp/install-vscode.sh && rm /tmp/install-vscode.sh

ARG USERNAME
ARG USER_UID=1000
ARG USER_GID=$USER_UID
ENV ANDROID_HOME=/home/${USERNAME}/Android/Sdk
ENV ANDROID_PROFILE_DIR=/home/${USERNAME}/android-profiles
ENV PATH=${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/emulator:/usr/local/nvm/current/bin:${PATH}
# Provision Android directly from the pinned android-profile submodule.
COPY --chown=${USER_UID}:${USER_GID} external/android-profile/scripts/ /home/${USERNAME}/bin/
COPY --chown=${USER_UID}:${USER_GID} external/android-profile/profiles/ /home/${USERNAME}/android-profiles/
COPY --chown=${USER_UID}:${USER_GID} base-scripts/ /home/${USERNAME}/bin/
COPY --chown=${USER_UID}:${USER_GID} docker/config/supervisor/android.supervisord.conf /home/${USERNAME}/supervisor/conf.d/android.supervisord.conf
RUN chmod +x /home/${USERNAME}/bin/*.sh

USER ${USERNAME}
WORKDIR /home/${USERNAME}
EXPOSE 22 5555 4723
