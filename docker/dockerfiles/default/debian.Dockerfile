ARG BASE_SYSTEM=debian
ARG BASE_VERSION=trixie
ARG DESKTOP_TYPE=xfce
ARG JDK_PROVIDER=openjdk
ARG OPENJDK_VERSION=21
ARG DESKTOP_IMAGE_REGION_SUFFIX=
ARG DESKTOP_IMAGE_LABEL=latest
ARG DESKTOP_BASE_IMAGE=storytellerf/desktop-in-docker:${BASE_SYSTEM}-${BASE_VERSION}-${DESKTOP_TYPE}${DESKTOP_IMAGE_REGION_SUFFIX}-${DESKTOP_IMAGE_LABEL}
FROM ${DESKTOP_BASE_IMAGE}

USER root
# Git belongs to the project image rather than a reusable Feature.
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends git && rm -rf /var/lib/apt/lists/*

ARG USERNAME
ENV ANDROID_HOME=/home/${USERNAME}/Android/Sdk
ENV ANDROID_PROFILE_DIR=/home/${USERNAME}/android-profiles
ENV PATH=${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/emulator:/usr/local/nvm/current/bin:${PATH}
USER ${USERNAME}
WORKDIR /home/${USERNAME}
EXPOSE 22 5555 4723
