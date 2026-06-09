#!/bin/bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/constants.sh
source "${SCRIPT_DIR}/constants.sh"

parse_mb() {
    case "$1" in
        *[Gg]) echo $(( ${1%[Gg]} * 1024 )) ;;
        *[Mm]) echo "${1%[Mm]}" ;;
        *)     echo $(( $1 / 1048576 )) ;;
    esac
}

is_percentage() {
    [[ "${1:-}" == *% ]]
}

read_limit_mb() {
    local cgv2="${1:-/sys/fs/cgroup/memory.max}"
    local cgv1="${2:-/sys/fs/cgroup/memory/memory.limit_in_bytes}"
    local meminfo="${3:-/proc/meminfo}"

    if [ -f "$cgv2" ]; then
        read -r val < "$cgv2"
        [ "$val" != "max" ] && echo $(( val / 1048576 )) && return
    fi
    if [ -f "$cgv1" ]; then
        read -r val < "$cgv1"
        [ "$val" -lt 9223372036854771712 ] 2>/dev/null && echo $(( val / 1048576 )) && return
    fi
    awk '/MemTotal/ {print int($2 / 1024)}' "$meminfo"
}

get_security_jvm_opts() {
    echo "-Dlog4j2.formatMsgNoLookups=true -javaagent:/usr/local/bin/Log4jPatcher.jar -javaagent:/usr/local/bin/serializationisbad.jar"
}

download_and_verify() {
    local url="$1" output="$2" label="${3:-file}"
    echo "Downloading ${label}..."
    for i in $(seq 1 "$DOWNLOAD_RETRIES"); do
        wget -T "${WGET_TIMEOUT}" -O "$output" "$url" && break
        echo "Download attempt $i failed, retrying..."
        sleep "$DOWNLOAD_RETRY_DELAY"
    done
    if [ ! -s "$output" ]; then
        echo "ERROR: Failed to download ${label} after ${DOWNLOAD_RETRIES} attempts" >&2
        return 1
    fi
    if ! head -c 2 "$output" | grep -q 'PK'; then
        echo "ERROR: Downloaded ${label} does not appear to be a valid ZIP/JAR" >&2
        return 1
    fi
}

download_and_verify_large() {
    local url="$1" output="$2" label="${3:-file}"
    echo "Downloading ${label}..."
    for i in $(seq 1 "$DOWNLOAD_RETRIES"); do
        wget -T "${WGET_TIMEOUT_LARGE}" -O "$output" "$url" && break
        echo "Download attempt $i failed, retrying..."
        sleep "$DOWNLOAD_RETRY_DELAY"
    done
    if [ ! -s "$output" ]; then
        echo "ERROR: Failed to download ${label} after ${DOWNLOAD_RETRIES} attempts" >&2
        return 1
    fi
    if ! head -c 2 "$output" | grep -q 'PK'; then
        echo "ERROR: Downloaded ${label} does not appear to be a valid ZIP/JAR" >&2
        return 1
    fi
}

check_eula() {
    if [ "${EULA:-}" = "TRUE" ]; then
        echo "eula=true" > eula.txt
        return 0
    fi
    echo "You must accept the Minecraft EULA to run this server." >&2
    echo "Set the environment variable EULA=TRUE to indicate acceptance." >&2
    echo "The EULA can be found at: https://aka.ms/MinecraftEULA" >&2
    return 1
}

calculate_heap_size() {
    local memory="${1:-}"
    local limit_mb="$2"

    if [ -n "$memory" ]; then
        echo "$memory"
        return
    fi

    local reserved_mb
    if [ -n "${SYSTEM_RESERVED:-}" ]; then
        reserved_mb=$(parse_mb "$SYSTEM_RESERVED")
    else
        reserved_mb=$(( limit_mb * DEFAULT_RESERVED_PCT / 100 ))
        [ "$reserved_mb" -lt "$MIN_RESERVED_MB" ] && reserved_mb="$MIN_RESERVED_MB"
        [ "$reserved_mb" -gt "$MAX_RESERVED_MB" ] && reserved_mb="$MAX_RESERVED_MB"
    fi
    local heap_mb=$(( limit_mb - reserved_mb ))
    [ "$heap_mb" -lt "$MIN_HEAP_MB" ] && heap_mb="$MIN_HEAP_MB"
    echo "${heap_mb}M"
}

build_java_memory_args() {
    local init_mem="${1:-}" max_mem="${2:-}"
    local args=""
    if is_percentage "$init_mem"; then
        args="$args -XX:InitialRAMPercentage=${init_mem%\%}"
    elif [ -n "$init_mem" ]; then
        args="$args -Xms${init_mem}"
    fi
    if is_percentage "$max_mem"; then
        args="$args -XX:MaxRAMPercentage=${max_mem%\%}"
    elif [ -n "$max_mem" ]; then
        args="$args -Xmx${max_mem}"
    fi
    echo "${args# }"
}

build_g1gc_flags() {
    local max_mem="$1"

    local a_heap=8M a_new=30 a_max_new=40 a_reserve=20 a_mixed=4 a_ihop=15 a_rset=5
    if ! is_percentage "$max_mem"; then
        local flags_mb
        flags_mb=$(parse_mb "$max_mem" 2>/dev/null || echo 0)
        if [ "$flags_mb" -ge "$LARGE_HEAP_THRESHOLD_MB" ]; then
            a_heap=16M
            a_new=40
            a_max_new=50
            a_reserve=15
            a_ihop=20
        fi
    fi

    echo "-XX:+AlwaysPreTouch \
-XX:+DisableExplicitGC \
-XX:+PerfDisableSharedMem \
-XX:+UnlockExperimentalVMOptions \
-XX:G1HeapRegionSize=${a_heap} \
-XX:G1HeapWastePercent=5 \
-XX:G1MaxNewSizePercent=${a_max_new} \
-XX:G1MixedGCCountTarget=${a_mixed} \
-XX:G1MixedGCLiveThresholdPercent=90 \
-XX:G1NewSizePercent=${a_new} \
-XX:G1RSetUpdatingPauseTimePercent=${a_rset} \
-XX:G1ReservePercent=${a_reserve} \
-XX:InitiatingHeapOccupancyPercent=${a_ihop} \
-XX:MaxGCPauseMillis=200 \
-Dusing.aikars.flags=https://flags.sh \
-Daikars.new.flags=true"
}

build_zgc_flags() {
    echo "-XX:+UseZGC \
-XX:+AlwaysPreTouch \
-XX:+DisableExplicitGC \
-XX:+PerfDisableSharedMem"
}

build_gc_flags() {
    local max_mem="$1"
    local gc_type="${GC_TYPE:-zgc}"

    case "$gc_type" in
        zgc)  build_zgc_flags ;;
        g1gc) build_g1gc_flags "$max_mem" ;;
        *)
            echo "WARNING: Unknown GC_TYPE '${gc_type}'. Falling back to ZGC." >&2
            build_zgc_flags
            ;;
    esac
}
