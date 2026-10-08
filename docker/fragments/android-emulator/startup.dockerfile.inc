# Copy the SDK/AVD/emulator startup wrapper. The image template registers android.supervisord.conf.
ARG USERNAME
ARG USER_UID=1000
ARG USER_GID=$USER_UID

USER root
COPY --chown=${USER_UID}:${USER_GID} base-scripts/start-android.sh /home/${USERNAME}/bin/start-android.sh
RUN chmod +x /home/${USERNAME}/bin/start-android.sh
EXPOSE 5555
