ARG BASE_SYSTEM=alpine
ARG BASE_VERSION=latest
ARG DESKTOP_TYPE=xfce
ARG JDK_PROVIDER=openjdk
ARG OPENJDK_VERSION=21
ARG BASE_IMAGE_VARIANT_SUFFIX=
ARG BASE_IMAGE_SOURCE_LABEL=latest
FROM storytellerf/android-in-docker:${BASE_SYSTEM}-${BASE_VERSION}-${DESKTOP_TYPE}-${JDK_PROVIDER}${OPENJDK_VERSION}${BASE_IMAGE_VARIANT_SUFFIX}-${BASE_IMAGE_SOURCE_LABEL}

ARG USERNAME=alpine

USER root

RUN apk add --no-cache \
    android-tools \
    qemu-img \
    qemu-system-x86_64

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
	add_group_for_gid 993 hostkvm2; \
	add_group_for_gid 46 hostplugdev

ARG USER_UID=1000
ARG USER_GID=$USER_UID

USER $USERNAME
WORKDIR /home/$USERNAME

COPY --chown=${USER_UID}:${USER_GID} base-scripts ./bin
COPY --chown=${USER_UID}:${USER_GID} external/android-profile/scripts ./bin
COPY --chown=${USER_UID}:${USER_GID} external/android-profile/profiles ./android-profiles
RUN chmod +x ./bin/*.sh

RUN ./bin/install-appium.sh

COPY --chown=${USER_UID}:${USER_GID} docker/config/supervisor/android.supervisord.conf /home/${USERNAME}/supervisor/conf.d/android.supervisord.conf

ENV ANDROID_HOME=/home/${USERNAME}/Android/Sdk
ENV PATH=$PATH:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/emulator

EXPOSE 5555 4723
