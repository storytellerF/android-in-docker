ARG BASE_SYSTEM=fedora
ARG BASE_VERSION=44
ARG DESKTOP_TYPE=xfce
ARG JDK_PROVIDER=openjdk
ARG OPENJDK_VERSION=21
ARG BASE_IMAGE_VARIANT_SUFFIX=
ARG BASE_IMAGE_SOURCE_LABEL=latest
FROM storytellerf/android-in-docker:${BASE_SYSTEM}-${BASE_VERSION}-${DESKTOP_TYPE}-${JDK_PROVIDER}${OPENJDK_VERSION}${BASE_IMAGE_VARIANT_SUFFIX}-${BASE_IMAGE_SOURCE_LABEL}

USER root

RUN dnf install -y \
    ca-certificates \
    curl \
    git \
    gnupg2 \
    openssh-server \
    rpm \
    tar \
    wget \
    && dnf clean all

RUN rpm --import https://packages.microsoft.com/keys/microsoft.asc \
    && printf '[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc\n' \
        > /etc/yum.repos.d/vscode.repo

RUN dnf install -y code \
    && dnf clean all

RUN sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

RUN mkdir -p /run/sshd

ARG USER_NAME=user
ARG USER_UID=1000
ARG USER_GID=$USER_UID

USER $USER_NAME
WORKDIR /home/$USER_NAME

COPY --chown=${USER_UID}:${USER_GID} download/android-studio-*.tar.gz /home/${USER_NAME}/Applications/android-studio.tar.gz
RUN mkdir -p Applications \
    && tar -xzf ./Applications/android-studio.tar.gz -C ./Applications \
    && rm ./Applications/android-studio.tar.gz

RUN mkdir -p /home/${USER_NAME}/Desktop \
    && printf "[Desktop Entry]\nVersion=1.0\nType=Application\nName=Android Studio\nExec=studio\nIcon=/home/${USER_NAME}/Applications/android-studio/bin/studio.svg\nTerminal=false\nCategories=Development;IDE;" > /home/${USER_NAME}/Desktop/android-studio.desktop \
    && chmod +x /home/${USER_NAME}/Desktop/android-studio.desktop

COPY --chown=${USER_UID}:${USER_GID} docker/config/supervisor/ssh.supervisord.conf /home/${USER_NAME}/supervisor/conf.d/ssh.supervisord.conf
COPY --chown=${USER_UID}:${USER_GID} scripts/start-ssh.sh /home/${USER_NAME}/bin/start-ssh.sh
RUN chmod +x /home/${USER_NAME}/bin/start-ssh.sh

ENV PATH="/home/${USER_NAME}/Applications/android-studio/bin:${PATH}"

EXPOSE 22
