# Configure key authentication and register the SSH service.
ARG USERNAME
ARG USER_UID=1000
ARG USER_GID=$USER_UID

USER root
RUN sed -i 's/^#*PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/^#*PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && mkdir -p /run/sshd

COPY --chown=${USER_UID}:${USER_GID} docker/config/supervisor/ssh.supervisord.conf /home/${USERNAME}/supervisor/conf.d/ssh.supervisord.conf
COPY --chown=${USER_UID}:${USER_GID} scripts/start-ssh.sh /home/${USERNAME}/bin/start-ssh.sh
RUN chmod +x /home/${USERNAME}/bin/start-ssh.sh

EXPOSE 22
