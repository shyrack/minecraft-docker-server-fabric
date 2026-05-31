FROM amazoncorretto:26-alpine

RUN apk add --no-cache bash curl gcompat netcat-openbsd && \
    apk upgrade --no-cache

ARG FABRIC_LOADER=0.19.2
ARG MINECRAFT_VERSION=26.1.2
ARG INSTALLER_VERSION=1.1.1

ENV FABRIC_LOADER=${FABRIC_LOADER} \
    MINECRAFT_VERSION=${MINECRAFT_VERSION} \
    INSTALLER_VERSION=${INSTALLER_VERSION}

RUN adduser -D -h /usr/local/minecraft minecraft

WORKDIR /usr/local/minecraft

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh && \
    chown -R minecraft:minecraft /usr/local/minecraft /usr/local/bin/entrypoint.sh

USER minecraft

EXPOSE 25565
VOLUME /usr/local/minecraft

HEALTHCHECK --interval=30s --timeout=10s --start-period=300s --retries=3 \
    CMD nc -z localhost 25565 || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
