# Register SDK installation, AVD creation, and emulator startup with Supervisor.
ARG USERNAME
ARG USER_UID=1000
ARG USER_GID=$USER_UID

USER root
COPY --chown=${USER_UID}:${USER_GID} base-scripts/start-android.sh /home/${USERNAME}/bin/start-android.sh
COPY --chown=${USER_UID}:${USER_GID} docker/config/supervisor/emulator.supervisord.conf /home/${USERNAME}/supervisor/conf.d/emulator.supervisord.conf
RUN chmod +x /home/${USERNAME}/bin/start-android.sh
EXPOSE 5555
