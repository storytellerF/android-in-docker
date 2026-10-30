FROM node:24-bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends sudo && rm -rf /var/lib/apt/lists/*
COPY features/_common/ /tmp/_common/
COPY features/nodejs/configure-npm.sh /tmp/configure-npm.sh
