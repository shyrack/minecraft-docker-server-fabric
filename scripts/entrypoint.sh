#!/bin/bash
set -eu

SCRIPTS_DIR="$(dirname "$0")"
# shellcheck source=scripts/runtime-functions.sh
. "${SCRIPTS_DIR}/runtime-functions.sh"

SERVER_TYPE="${SERVER_TYPE:-fabric}"
PROVIDER_FILE="${SCRIPTS_DIR}/providers/${SERVER_TYPE}.sh"

if [ ! -f "$PROVIDER_FILE" ]; then
    echo "ERROR: Unknown server type '${SERVER_TYPE}'." >&2
    echo "Supported types: fabric, paper, spigot, neoforge, forge, vanilla" >&2
    exit 1
fi

# shellcheck source=scripts/providers/fabric.sh
. "$PROVIDER_FILE"

provider_resolve_version

provider_download_server

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

SERVER_JAR=$(provider_get_jar)
LAUNCH_ARGS=$(provider_get_launch_args)

if [ -n "$SERVER_JAR" ]; then
    # shellcheck disable=SC2086
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
        -jar "$SERVER_JAR" $LAUNCH_ARGS
else
    # shellcheck disable=SC2086
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
        $LAUNCH_ARGS
fi
