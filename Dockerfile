ARG BASE_SYSTEM=debian
ARG BASE_VERSION=trixie
ARG DESKTOP_TYPE=xfce
ARG JDK_PROVIDER=openjdk
ARG OPENJDK_VERSION=21
ARG BASE_IMAGE_VARIANT_SUFFIX=
ARG BASE_IMAGE_SOURCE_LABEL=latest
FROM storytellerf/android-in-docker:${BASE_SYSTEM}-${BASE_VERSION}-${DESKTOP_TYPE}-${JDK_PROVIDER}${OPENJDK_VERSION}${BASE_IMAGE_VARIANT_SUFFIX}-${BASE_IMAGE_SOURCE_LABEL}

ARG USERNAME=debian
ARG USE_CN_ENV=false

USER root

# Install system packages shared by all Android images.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends --no-install-suggests \
    qemu-kvm \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
	add_group_for_gid() { \
		gid="$1"; \
		fallback_name="$2"; \
		if getent group "$gid" >/dev/null; then \
			group_name="$(getent group "$gid" | cut -d: -f1)"; \
		else \
			group_name="$fallback_name"; \
			groupadd -g "$gid" "$group_name"; \
		fi; \
		usermod -aG "$group_name" "$USERNAME"; \
	}; \
	add_group_for_gid 992 hostkvm1; \
	add_group_for_gid 993 hostkvm2

ARG USER_UID=1000
ARG USER_GID=$USER_UID

USER $USERNAME
WORKDIR /home/$USERNAME

# Copy Scripts
COPY --chown=${USER_UID}:${USER_GID} base-scripts ./bin
RUN chmod +x ./bin/*.sh

# Install Appium
RUN ./bin/install-appium.sh

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
