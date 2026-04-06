ARG BASE_SYSTEM=debian
ARG BASE_VERSION=trixie
ARG DESKTOP_TYPE=xfce
FROM storytellerf/desktop-in-docker:${BASE_SYSTEM}-${BASE_VERSION}-${DESKTOP_TYPE}-latest

ARG OPENJDK_VERSION=21

USER root

# Install system packages shared by all Android images.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends --no-install-suggests \
    openjdk-${OPENJDK_VERSION}-jdk \
    && rm -rf /var/lib/apt/lists/*