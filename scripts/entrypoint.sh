#!/bin/bash
set -eu

SCRIPTS_DIR="$(dirname "$0")"
# shellcheck source=scripts/runtime-functions.sh
. "${SCRIPTS_DIR}/runtime-functions.sh"

SERVER_TYPE="${SERVER_TYPE:-${DEFAULT_SERVER_TYPE}}"
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

check_eula || exit 1

if [ -n "${MEMORY:-}" ]; then
    HEAP_SIZE="$MEMORY"
else
    LIMIT_MB=$(read_limit_mb)
    HEAP_SIZE=$(calculate_heap_size "" "$LIMIT_MB")
fi

: "${INIT_MEMORY=${HEAP_SIZE}}"
: "${MAX_MEMORY=${HEAP_SIZE}}"

JAVA_MEM_ARGS=$(build_java_memory_args "$INIT_MEMORY" "$MAX_MEMORY")
GC_FLAGS=$(build_gc_flags "$MAX_MEMORY")

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
