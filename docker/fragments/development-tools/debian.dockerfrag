USER root
RUN apt update && DEBIAN_FRONTEND=noninteractive \
    apt install -y --no-install-recommends --no-install-suggests curl extrepo gnupg2 git && \
    rm -rf /var/lib/apt/lists/*
