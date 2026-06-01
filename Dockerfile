FROM amazoncorretto:26-alpine

USER root

# hadolint ignore=DL3018
RUN apk add --no-cache bash gcompat jq netcat-openbsd && \
    apk upgrade --no-cache

ARG MINECRAFT_VERSION=latest

ENV MINECRAFT_VERSION=${MINECRAFT_VERSION} \
    SERVER_TYPE=fabric

RUN adduser -D -h /usr/local/minecraft minecraft

WORKDIR /usr/local/minecraft

COPY scripts/runtime-functions.sh /usr/local/bin/runtime-functions.sh
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/providers/ /usr/local/bin/providers/

RUN chmod +x /usr/local/bin/entrypoint.sh && \
    chmod +x /usr/local/bin/providers/*.sh && \
    chown -R minecraft:minecraft /usr/local/minecraft /usr/local/bin

USER minecraft

EXPOSE 25565
VOLUME /usr/local/minecraft

HEALTHCHECK --interval=30s --timeout=10s --start-period=300s --retries=3 \
    CMD nc -z localhost 25565 || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
