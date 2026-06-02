FROM eclipse-temurin:26-jdk-alpine

USER root

# hadolint ignore=DL3018
RUN apk add --no-cache bash gcompat jq netcat-openbsd && \
    apk upgrade --no-cache

RUN wget -q -O /usr/local/bin/Log4jPatcher.jar \
    https://github.com/CreeperHost/Log4jPatcher/releases/download/v1.0.1/Log4jPatcher-1.0.1.jar && \
    wget -q -O /usr/local/bin/serializationisbad.jar \
    https://github.com/dogboy21/serializationisbad/releases/download/1.5.2/serializationisbad-1.5.2.jar && \
    wget -q -O /usr/local/bin/serializationisbad.json \
    https://raw.githubusercontent.com/dogboy21/serializationisbad/master/serializationisbad.json

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
