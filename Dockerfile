ARG BASE_SYSTEM=debian
ARG BASE_VERSION=trixie
ARG DESKTOP_TYPE=xfce
ARG OPENJDK_VERSION=21
ARG BASE_IMAGE_VARIANT_SUFFIX=
ARG BASE_IMAGE_SOURCE_LABEL=latest
FROM storytellerf/android-in-docker:${BASE_SYSTEM}-${BASE_VERSION}-${DESKTOP_TYPE}-openjdk${OPENJDK_VERSION}${BASE_IMAGE_VARIANT_SUFFIX}-${BASE_IMAGE_SOURCE_LABEL}

ARG USERNAME=debian
ARG USE_CN_ENV=false

USER root

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

RUN if [ "$USE_CN_ENV" = "true" ]; then \
	apt-get update && \
	DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends --no-install-suggests fcitx fcitx-googlepinyin && \
	install -d -m 0755 /etc/docker && \
	printf '{\n  "registry-mirrors": [\n    "https://docker.1ms.run",\n    "https://docker.1panel.live",\n    "https://docker.m.daocloud.io"\n  ]\n}\n' > /etc/docker/daemon.json && \
	rm -rf /var/lib/apt/lists/*; \
fi

ARG USER_UID=1000
ARG USER_GID=$USER_UID

USER $USERNAME
WORKDIR /home/$USERNAME

# Copy Scripts
COPY --chown=${USER_UID}:${USER_GID} base-scripts ./bin
RUN chmod +x ./bin/*.sh

# Install Appium and Node.js
RUN ./bin/install-appium.sh false

COPY --chown=${USER_UID}:${USER_GID} fcitx ./fcitx-defaults
RUN if [ "$USE_CN_ENV" = "true" ]; then \
		mkdir -p .config/fcitx && \
		install -m 644 fcitx-defaults/config .config/fcitx/config && \
		install -m 644 fcitx-defaults/profile .config/fcitx/profile; \
fi && \
rm -rf fcitx-defaults

RUN mkdir -p log/supervisor run

# Copy supervisor configuration
COPY --chown=${USER_UID}:${USER_GID} android.supervisord.conf /home/${USERNAME}/supervisor/conf.d/android.supervisord.conf

RUN if [ "$USE_CN_ENV" = "true" ]; then \
		{ \
			echo '[program:fcitx]'; \
			echo 'command=/usr/bin/fcitx -D'; \
			echo 'environment=USER=%(ENV_SUPERVISOR_USER)s,HOME=%(ENV_HOME)s,DISPLAY=:1'; \
			echo 'stdout_logfile=%(ENV_HOME)s/log/supervisor/fcitx_stdout.log'; \
			echo 'stderr_logfile=%(ENV_HOME)s/log/supervisor/fcitx_stderr.log'; \
			echo 'autorestart=false'; \
			echo 'user=%(ENV_SUPERVISOR_USER)s'; \
			echo 'stopasgroup=true'; \
			echo 'killasgroup=true'; \
		} > supervisor/conf.d/fcitx.supervisord.conf; \
fi

# Setup Android SDK Environment
ENV ANDROID_HOME=/home/${USERNAME}/Android/Sdk
ENV PATH=$PATH:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/emulator

# Expose Ports:
# 5555: ADB port
# 4723: Appium port
EXPOSE 5555 4723
