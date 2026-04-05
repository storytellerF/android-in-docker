ARG BASE_SYSTEM=debian
ARG BASE_VERSION=trixie
ARG DESKTOP_TYPE=xfce
FROM storytellerf/desktop-in-docker:${BASE_SYSTEM}-${BASE_VERSION}-${DESKTOP_TYPE}-latest

ARG OPENJDK_VERSION=21
ARG USERNAME=debian

USER root

# Install Dependencies: Java, KVM, and other tools
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends --no-install-suggests \
    openjdk-${OPENJDK_VERSION}-jdk \
    qemu-kvm \
    npm \
	jq \
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
ARG USE_CN_ENV=false

# Install fcitx input method
RUN if [ "$USE_CN_ENV" = "true" ]; then \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y fcitx fcitx-googlepinyin && \
    rm -rf /var/lib/apt/lists/*; \
fi

USER $USERNAME
WORKDIR /home/$USERNAME

# Copy Scripts
COPY --chown=${USER_UID}:${USER_GID} base-scripts ./bin
RUN chmod +x ./bin/*.sh

# Install Appium and Node.js
RUN ./bin/install-appium.sh $USE_CN_ENV

RUN mkdir -p log/supervisor run

# Copy supervisor configuration
COPY --chown=${USER_UID}:${USER_GID} android.supervisord.conf /home/${USERNAME}/supervisor/conf.d/android.supervisord.conf

# Setup fcitx supervisord config
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
