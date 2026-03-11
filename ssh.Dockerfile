FROM storytellerf/android-in-docker:snapshot

USER root

RUN apt update && apt install -y openssh-server

# RUN echo "debian:123456" | chpasswd

# 开启公钥认证，禁用密码登录（可选但推荐）
RUN sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

USER debian

EXPOSE 22
