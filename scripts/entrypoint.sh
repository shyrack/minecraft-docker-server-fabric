#!/bin/sh
set -eu

. "$(dirname "$0")/runtime-functions.sh"

if [ "${MINECRAFT_VERSION}" = "latest" ] || [ "${FABRIC_LOADER}" = "latest" ] || [ "${INSTALLER_VERSION}" = "latest" ]; then
    resolve_latest() {
        wget -T 30 -q -O - "$1" | awk -F'"' '/"version"/{v=$4} /"stable": *true/{print v; exit}'
    }
    if [ "${MINECRAFT_VERSION}" = "latest" ]; then
        MINECRAFT_VERSION=$(resolve_latest "https://meta.fabricmc.net/v2/versions/game")
    fi
    if [ "${FABRIC_LOADER}" = "latest" ]; then
        FABRIC_LOADER=$(resolve_latest "https://meta.fabricmc.net/v2/versions/loader/${MINECRAFT_VERSION}")
    fi
    if [ "${INSTALLER_VERSION}" = "latest" ]; then
        INSTALLER_VERSION=$(resolve_latest "https://meta.fabricmc.net/v2/versions/installer")
    fi
fi

if [ ! -f fabric-server.jar ]; then
    echo "Downloading fabric-server.jar…"
    for i in 1 2 3; do
        wget -T 30 -O fabric-server.jar \
            "https://meta.fabricmc.net/v2/versions/loader/${MINECRAFT_VERSION}/${FABRIC_LOADER}/${INSTALLER_VERSION}/server/jar" \
            && break
        echo "Download attempt $i failed, retrying…"
        sleep 5
    done

    if [ ! -s fabric-server.jar ]; then
        echo "ERROR: Failed to download fabric-server.jar after 3 attempts" >&2
        exit 1
    fi

    if ! head -c 2 fabric-server.jar | grep -q 'PK'; then
        echo "ERROR: Downloaded file does not appear to be a valid ZIP/JAR" >&2
        exit 1
    fi
fi

if [ "${EULA:-}" = "TRUE" ]; then
    echo "eula=true" > eula.txt
else
    echo "You must accept the Minecraft EULA to run this server." >&2
    echo "Set the environment variable EULA=TRUE to indicate acceptance." >&2
    echo "The EULA can be found at: https://aka.ms/MinecraftEULA" >&2
    exit 1
fi

if [ -n "${MEMORY:-}" ]; then
    HEAP_SIZE="$MEMORY"
else
    SYS_RES="${SYSTEM_RESERVED:-1G}"
    RESERVED_MB=$(parse_mb "$SYS_RES")
    LIMIT_MB=$(read_limit_mb)
    HEAP_MB=$(( LIMIT_MB - RESERVED_MB ))
    [ "$HEAP_MB" -lt 512 ] && HEAP_MB=512
    HEAP_SIZE="${HEAP_MB}M"
fi

JAVA_MEM_ARGS="-Xms${HEAP_SIZE} -Xmx${HEAP_SIZE}"

exec java \
    ${JAVA_MEM_ARGS} \
    -XX:+AlwaysPreTouch \
    -XX:+DisableExplicitGC \
    -XX:+PerfDisableSharedMem \
    -XX:G1HeapRegionSize=8M \
    -XX:G1HeapWastePercent=5 \
    -XX:G1MaxNewSizePercent=40 \
    -XX:G1MixedGCCountTarget=4 \
    -XX:G1MixedGCLiveThresholdPercent=90 \
    -XX:G1NewSizePercent=30 \
    -XX:G1RSetUpdatingPauseTimePercent=5 \
    -XX:G1ReservePercent=20 \
    -XX:InitiatingHeapOccupancyPercent=15 \
    -XX:MaxGCPauseMillis=200 \
    -Dusing.aikars.flags=https://flags.sh \
    -Daikars.new.flags=true \
    -jar fabric-server.jar nogui
