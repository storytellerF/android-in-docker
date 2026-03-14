FROM storytellerf/android-in-docker:latest

ARG USER_NAME=debian

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

# install antigravity
RUN mkdir -p /etc/apt/keyrings
RUN curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg | \
    gpg --dearmor --yes -o /etc/apt/keyrings/antigravity-repo-key.gpg
RUN echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" | \
    tee /etc/apt/sources.list.d/antigravity.list > /dev/null
RUN apt update && DEBIAN_FRONTEND=noninteractive \
    apt install -y antigravity && \
    rm -f /etc/apt/sources.list.d/antigravity.list

# 开启公钥认证，禁用密码登录（可选但推荐）
RUN sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# 复制并解压 Android Studio
# 假设已经将 android-studio-*.tar.gz 下载到 download 目录，不适用tmp 目录
COPY --chown=${USER_NAME}:${USER_NAME} download/android-studio-*.tar.gz /home/${USER_NAME}/Applications/android-studio.tar.gz
COPY --chown=${USER_NAME}:${USER_NAME} ssh.supervisord.conf /home/${USER_NAME}/supervisor/conf.d/ssh.supervisord.conf
COPY --chown=${USER_NAME}:${USER_NAME} scripts/start-ssh.sh /home/${USER_NAME}/bin/start-ssh.sh
RUN chmod +x /home/${USER_NAME}/bin/start-ssh.sh

USER $USER_NAME
WORKDIR /home/$USER_NAME

RUN mkdir -p Applications && \
    tar -xzf ./Applications/android-studio.tar.gz -C ./Applications && \
    rm ./Applications/android-studio.tar.gz

# 创建桌面快捷方式
RUN mkdir -p /home/${USER_NAME}/Desktop && \
    printf "[Desktop Entry]\nVersion=1.0\nType=Application\nName=Android Studio\nExec=studio\nIcon=/home/${USER_NAME}/Applications/android-studio/bin/studio.svg\nTerminal=false\nCategories=Development;IDE;" > /home/${USER_NAME}/Desktop/android-studio.desktop && \
    chmod +x /home/${USER_NAME}/Desktop/android-studio.desktop

RUN mkdir -p .config .local .cache .gemini .ssh

# 替换 entrypoint.sh 注入点，确保每次启动容器时都能清理 Chrome 的 Singleton 锁文件，避免 Chrome 无法启动的问题
RUN sed -i "/# inject point/a rm -f /home/${USER_NAME}/.config/google-chrome/Singleton*" /home/${USER_NAME}/bin/entrypoint.sh

# 设置环境变量
ENV PATH="/home/${USER_NAME}/Applications/android-studio/bin:${PATH}"

EXPOSE 22