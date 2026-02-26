FROM storytellerf/android-in-docker:snapshot

USER root

RUN apt update && apt install -y extrepo fonts-noto
RUN sed -i 's/# - non-free/- non-free/' /etc/extrepo/config.yaml
RUN extrepo enable google_chrome
RUN apt update && apt install -y google-chrome-stable \
    && rm -f /etc/apt/sources.list.d/google-chrome*.list

USER debian
