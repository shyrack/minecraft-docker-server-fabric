#!/bin/sh
set -eu

if [ ! -f fabric-server.jar ]; then
    echo "Downloading fabric-server.jar…"
    curl -fLo fabric-server.jar \
        "https://meta.fabricmc.net/v2/versions/loader/${MINECRAFT_VERSION}/${FABRIC_LOADER}/${INSTALLER_VERSION}/server/jar"
fi

if [ "${EULA:-}" = "TRUE" ]; then
    echo "eula=true" > eula.txt
else
    echo "You must accept the Minecraft EULA to run this server." >&2
    echo "Set the environment variable EULA=TRUE to indicate acceptance." >&2
    echo "The EULA can be found at: https://aka.ms/MinecraftEULA" >&2
    exit 1
fi

parse_mb() {
    case "$1" in
        *[Gg]) echo $(( ${1%[Gg]} * 1024 )) ;;
        *[Mm]) echo "${1%[Mm]}" ;;
        *)     echo $(( $1 / 1048576 )) ;;
    esac
}

read_limit_mb() {
    if [ -f /sys/fs/cgroup/memory.max ]; then
        read -r val < /sys/fs/cgroup/memory.max
        [ "$val" != "max" ] && echo $(( val / 1048576 )) && return
    fi
    if [ -f /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
        read -r val < /sys/fs/cgroup/memory/memory.limit_in_bytes
        [ "$val" -lt 9223372036854771712 ] 2>/dev/null && echo $(( val / 1048576 )) && return
    fi
    awk '/MemTotal/ {print int($2 / 1024)}' /proc/meminfo
}

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

# shellcheck disable=SC2086
exec java \
    ${JAVA_MEM_ARGS} \
    -XX:+UseContainerSupport \
    -XX:+AlwaysPreTouch \
    -XX:+DisableExplicitGC \
    -XX:+PerfDisableSharedMem \
    -XX:+UnlockExperimentalVMOptions \
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
