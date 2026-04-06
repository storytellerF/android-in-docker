ARG BASE_SYSTEM=debian
ARG BASE_VERSION=trixie
ARG DESKTOP_TYPE=xfce
FROM storytellerf/desktop-in-docker:${BASE_SYSTEM}-${BASE_VERSION}-${DESKTOP_TYPE}-latest

ARG OPENJDK_VERSION=21

USER root

# Install Temurin from Adoptium so newer JDK versions are not tied to distro packages.
RUN set -eux; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends --no-install-suggests \
    apt-transport-https \
    ca-certificates \
    gpg \
    wget; \
    wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public \
        | gpg --dearmor \
        | tee /etc/apt/trusted.gpg.d/adoptium.gpg > /dev/null; \
    distro_codename="$(awk -F= '/^(VERSION_CODENAME|UBUNTU_CODENAME)=/{print $2; exit}' /etc/os-release)"; \
    echo "deb https://packages.adoptium.net/artifactory/deb ${distro_codename} main" \
        > /etc/apt/sources.list.d/adoptium.list; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends --no-install-suggests \
    temurin-${OPENJDK_VERSION}-jdk; \
    rm -rf /var/lib/apt/lists/*