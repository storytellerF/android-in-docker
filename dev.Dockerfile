ARG DESKTOP_TYPE=xfce
FROM storytellerf/android-in-docker:trixie-${DESKTOP_TYPE}-openjdk21-latest

USER root
RUN apt update && DEBIAN_FRONTEND=noninteractive \
    apt install -y --no-install-recommends --no-install-suggests curl openssh-server extrepo gnupg2 git && \
    apt install -y fonts-noto && \
    rm -rf /var/lib/apt/lists/*

# install chrome
RUN sed -i 's/# - non-free/- non-free/' /etc/extrepo/config.yaml
RUN extrepo enable google_chrome
RUN apt update && DEBIAN_FRONTEND=noninteractive \
    apt install -y google-chrome-stable \
    && rm -f /etc/apt/sources.list.d/google-chrome*.list

# install VS Code
RUN apt-get install -y wget gpg apt-transport-https && \
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg && \
    install -D -o root -g root -m 644 microsoft.gpg /usr/share/keyrings/microsoft.gpg && \
    rm -f microsoft.gpg && \
    printf 'Types: deb\nURIs: https://packages.microsoft.com/repos/code\nSuites: stable\nComponents: main\nArchitectures: amd64,arm64,armhf\nSigned-By: /usr/share/keyrings/microsoft.gpg\n' \
        > /etc/apt/sources.list.d/vscode.sources && \
    apt update && DEBIAN_FRONTEND=noninteractive \
    apt install -y code && \
    rm -rf /var/lib/apt/lists/*

# 开启公钥认证，禁用密码登录（可选但推荐）
RUN sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

RUN mkdir -p /run/sshd

ARG USER_NAME=debian
ARG USER_UID=1000
ARG USER_GID=$USER_UID

USER $USER_NAME
WORKDIR /home/$USER_NAME

# 复制并解压 Android Studio
# 假设已经将 android-studio-*.tar.gz 下载到 download 目录
COPY --chown=${USER_UID}:${USER_GID} download/android-studio-*.tar.gz /home/${USER_NAME}/Applications/android-studio.tar.gz
RUN mkdir -p Applications && \
    tar -xzf ./Applications/android-studio.tar.gz -C ./Applications && \
    rm ./Applications/android-studio.tar.gz
# 创建桌面快捷方式
RUN mkdir -p /home/${USER_NAME}/Desktop && \
    printf "[Desktop Entry]\nVersion=1.0\nType=Application\nName=Android Studio\nExec=studio\nIcon=/home/${USER_NAME}/Applications/android-studio/bin/studio.svg\nTerminal=false\nCategories=Development;IDE;" > /home/${USER_NAME}/Desktop/android-studio.desktop && \
    chmod +x /home/${USER_NAME}/Desktop/android-studio.desktop

COPY --chown=${USER_UID}:${USER_GID} ssh.supervisord.conf /home/${USER_NAME}/supervisor/conf.d/ssh.supervisord.conf
COPY --chown=${USER_UID}:${USER_GID} scripts/start-ssh.sh /home/${USER_NAME}/bin/start-ssh.sh
RUN chmod +x /home/${USER_NAME}/bin/start-ssh.sh

# 替换 entrypoint.sh 注入点，确保每次启动容器时都能清理 Chrome 的 Singleton 锁文件，避免 Chrome 无法启动的问题
RUN sed -i "/# inject point/a rm -f /home/${USER_NAME}/.config/google-chrome/Singleton*" /home/${USER_NAME}/bin/entrypoint.sh

# 设置环境变量
ENV PATH="/home/${USER_NAME}/Applications/android-studio/bin:${PATH}"

EXPOSE 22