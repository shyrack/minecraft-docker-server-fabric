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
    LIMIT_MB=$(read_limit_mb)
    if [ -n "${SYSTEM_RESERVED:-}" ]; then
        RESERVED_MB=$(parse_mb "$SYSTEM_RESERVED")
    else
        RESERVED_MB=$(( LIMIT_MB * 15 / 100 ))
        [ "$RESERVED_MB" -lt 512 ] && RESERVED_MB=512
        [ "$RESERVED_MB" -gt 1024 ] && RESERVED_MB=1024
    fi
    HEAP_MB=$(( LIMIT_MB - RESERVED_MB ))
    [ "$HEAP_MB" -lt 512 ] && HEAP_MB=512
    HEAP_SIZE="${HEAP_MB}M"
fi

: "${INIT_MEMORY=${HEAP_SIZE}}"
: "${MAX_MEMORY=${HEAP_SIZE}}"

JAVA_MEM_ARGS=""
if is_percentage "$INIT_MEMORY"; then
    JAVA_MEM_ARGS="$JAVA_MEM_ARGS -XX:InitialRAMPercentage=${INIT_MEMORY%\%}"
else
    JAVA_MEM_ARGS="$JAVA_MEM_ARGS -Xms${INIT_MEMORY}"
fi
if is_percentage "$MAX_MEMORY"; then
    JAVA_MEM_ARGS="$JAVA_MEM_ARGS -XX:MaxRAMPercentage=${MAX_MEMORY%\%}"
else
    JAVA_MEM_ARGS="$JAVA_MEM_ARGS -Xmx${MAX_MEMORY}"
fi

A_HEAP=8M
A_NEW=30
A_MAX_NEW=40
A_RESERVE=20
A_MIXED=4
A_IHOP=15
A_RSET=5
if ! is_percentage "$MAX_MEMORY"; then
    FLAGS_MB=$(parse_mb "$MAX_MEMORY" 2>/dev/null || echo 0)
else
    FLAGS_MB=0
fi
if [ "$FLAGS_MB" -ge 12288 ]; then
    A_HEAP=16M
    A_NEW=40
    A_MAX_NEW=50
    A_RESERVE=15
    A_IHOP=20
fi

GC_FLAGS="-XX:+AlwaysPreTouch \
-XX:+DisableExplicitGC \
-XX:+PerfDisableSharedMem \
-XX:+UnlockExperimentalVMOptions \
-XX:G1HeapRegionSize=${A_HEAP} \
-XX:G1HeapWastePercent=5 \
-XX:G1MaxNewSizePercent=${A_MAX_NEW} \
-XX:G1MixedGCCountTarget=${A_MIXED} \
-XX:G1MixedGCLiveThresholdPercent=90 \
-XX:G1NewSizePercent=${A_NEW} \
-XX:G1RSetUpdatingPauseTimePercent=${A_RSET} \
-XX:G1ReservePercent=${A_RESERVE} \
-XX:InitiatingHeapOccupancyPercent=${A_IHOP} \
-XX:MaxGCPauseMillis=200 \
-Dusing.aikars.flags=https://flags.sh \
-Daikars.new.flags=true"

CUSTOM_JVM_FLAGS="${JVM_XX_OPTS:-} ${JVM_OPTS:-}"
JAVA_SECURITY_OPTS=$(get_security_jvm_opts)

SERVER_JAR=$(provider_get_jar)
LAUNCH_ARGS=$(provider_get_launch_args)

mkdir -p config
cp -n /usr/local/bin/serializationisbad.json config/serializationisbad.json 2>/dev/null || true

STDIN_PIPE="/tmp/minecraft-stdin"
mkfifo -m 666 "$STDIN_PIPE" 2>/dev/null || true
sleep infinity > "$STDIN_PIPE" &
trap 'rm -f "$STDIN_PIPE"' EXIT

if [ -n "$SERVER_JAR" ]; then
    # shellcheck disable=SC2086
    exec java \
        ${JAVA_MEM_ARGS} \
        ${JAVA_SECURITY_OPTS} \
        ${CUSTOM_JVM_FLAGS} \
        ${GC_FLAGS} \
        -jar "$SERVER_JAR" $LAUNCH_ARGS < "$STDIN_PIPE"
else
    # shellcheck disable=SC2086
    exec java \
        ${JAVA_MEM_ARGS} \
        ${JAVA_SECURITY_OPTS} \
        ${CUSTOM_JVM_FLAGS} \
        ${GC_FLAGS} \
        $LAUNCH_ARGS < "$STDIN_PIPE"
fi
