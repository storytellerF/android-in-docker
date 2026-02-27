FROM storytellerf/android-in-docker:snapshot

USER root

# 复制并解压 Android Studio
# 假设已经将 android-studio-*.tar.gz 下载到 download 目录
COPY download/android-studio-*.tar.gz /tmp/android-studio.tar.gz

RUN mkdir -p /home/debian/Applications && \
    tar -xzf /tmp/android-studio.tar.gz -C /home/debian/Applications && \
    rm /tmp/android-studio.tar.gz

RUN chown -R debian:debian /home/debian/Applications/android-studio

# 设置环境变量
ENV PATH="/home/debian/Applications/android-studio/bin:${PATH}"

# 创建桌面快捷方式
RUN mkdir -p /home/debian/Desktop && \
    printf "[Desktop Entry]\nVersion=1.0\nType=Application\nName=Android Studio\nExec=studio\nIcon=/home/debian/Applications/android-studio/bin/studio.svg\nTerminal=false\nCategories=Development;IDE;" > /home/debian/Desktop/android-studio.desktop && \
    chmod +x /home/debian/Desktop/android-studio.desktop && \
    chown debian:debian /home/debian/Desktop/android-studio.desktop

USER debian