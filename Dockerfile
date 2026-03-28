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

RUN mkdir -p log/supervisor run

# Copy supervisor configuration
COPY --chown=${USER_UID}:${USER_GID} android.supervisord.conf /home/${USERNAME}/supervisor/conf.d/android.supervisord.conf

# Setup Android SDK Environment
ENV ANDROID_HOME=/home/${USERNAME}/Android/Sdk
ENV PATH=$PATH:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/emulator

# Expose Ports:
# 5555: ADB port
# 4723: Appium port
EXPOSE 5555 4723
