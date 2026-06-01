FROM amazoncorretto:26-alpine

USER root

RUN apk add --no-cache bash gcompat netcat-openbsd && \
    apk upgrade --no-cache

ARG FABRIC_LOADER=latest
ARG MINECRAFT_VERSION=latest
ARG INSTALLER_VERSION=latest

ENV FABRIC_LOADER=${FABRIC_LOADER} \
    MINECRAFT_VERSION=${MINECRAFT_VERSION} \
    INSTALLER_VERSION=${INSTALLER_VERSION}

RUN adduser -D -h /usr/local/minecraft minecraft

WORKDIR /usr/local/minecraft

COPY scripts/runtime-functions.sh /usr/local/bin/runtime-functions.sh
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh && \
    chown -R minecraft:minecraft /usr/local/minecraft /usr/local/bin/entrypoint.sh /usr/local/bin/runtime-functions.sh

USER minecraft

EXPOSE 25565
VOLUME /usr/local/minecraft

HEALTHCHECK --interval=30s --timeout=10s --start-period=300s --retries=3 \
    CMD nc -z localhost 25565 || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
