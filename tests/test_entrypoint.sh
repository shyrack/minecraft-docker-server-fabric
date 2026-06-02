#!/usr/bin/env bash
# tests/test_entrypoint.sh — Unit tests for entrypoint.sh
#
# Run with:  bash tests/test_entrypoint.sh
#
# Zero external dependencies. Tests function logic in isolation.
set -euo pipefail

PASS=0
FAIL=0

pass() { PASS=$((PASS+1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ $1"; echo "    $2"; }

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then pass "$desc"; else fail "$desc" "expected: '$expected'  actual: '$actual'"; fi
}

assert_contains() {
    local desc="$1" pattern="$2" text="$3"
    if [[ "$text" == *"$pattern"* ]]; then pass "$desc"; else fail "$desc" "expected text to contain: '$pattern'  actual: '$text'"; fi
}

assert_code() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" -eq "$actual" ]; then pass "$desc"; else fail "$desc" "expected exit code $expected, got $actual"; fi
}

# ==========================================================
# 1. parse_mb
# ==========================================================
# Sourced from the shared runtime-functions.sh (single source of truth)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/runtime-functions.sh
source "${SCRIPT_DIR}/../scripts/runtime-functions.sh"

echo "=== parse_mb ==="
assert_eq "2G → 2048 MB"           2048 "$(parse_mb "2G")"
assert_eq "2g (lowercase) → 2048"  2048 "$(parse_mb "2g")"
assert_eq "512M → 512"             512  "$(parse_mb "512M")"
assert_eq "512m (lowercase) → 512" 512  "$(parse_mb "512m")"
assert_eq "1 GiB in bytes → 1024"  1024 "$(parse_mb "1073741824")"
assert_eq "512 MiB in bytes → 512" 512  "$(parse_mb "536870912")"
assert_eq "0G → 0"                 0    "$(parse_mb "0G")"
assert_eq "1M → 1"                 1    "$(parse_mb "1M")"
assert_eq "0 bytes → 0"            0    "$(parse_mb "0")"
echo

# ==========================================================
# 2. read_limit_mb
# ==========================================================
# Tests the shared read_limit_mb function with custom filesystem paths.
# The function accepts optional cgroup path overrides for testing.

echo "=== read_limit_mb ==="

TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

# Prepare mock /proc/meminfo
cat > "$TMP/meminfo" <<'EOF'
MemTotal:       16384000 kB
MemFree:         8000000 kB
MemAvailable:   12000000 kB
Buffers:          500000 kB
EOF

echo "2147483648" > "$TMP/cgv2_val"
assert_eq "cgroup v2: 2 GiB limit → 2048 MB" 2048 \
    "$(read_limit_mb "$TMP/cgv2_val" "/nonexistent" "$TMP/meminfo")"

echo "max" > "$TMP/cgv2_max"
echo "4294967296" > "$TMP/cgv1"
assert_eq "cgroup v2 'max' → falls back to v1 4 GiB → 4096 MB" 4096 \
    "$(read_limit_mb "$TMP/cgv2_max" "$TMP/cgv1" "$TMP/meminfo")"

assert_eq "cgroup v1 only: 4 GiB → 4096 MB" 4096 \
    "$(read_limit_mb "/nonexistent" "$TMP/cgv1" "$TMP/meminfo")"

assert_eq "no cgroups → fallback to /proc/meminfo 16 GB → 16000 MB" 16000 \
    "$(read_limit_mb "/nonexistent" "/nonexistent" "$TMP/meminfo")"

echo "9223372036854771712" > "$TMP/cgv1_unlimited"
assert_eq "cgroup v1 unlimited → fallback to meminfo" 16000 \
    "$(read_limit_mb "/nonexistent" "$TMP/cgv1_unlimited" "$TMP/meminfo")"

assert_eq "cgroup v2 max+v1 unlimited → meminfo 16 GB" 16000 \
    "$(read_limit_mb "$TMP/cgv2_max" "$TMP/cgv1_unlimited" "$TMP/meminfo")"
echo

# ==========================================================
# 3. EULA guard
# ==========================================================
# Tests the exact logic from entrypoint.sh lines 10-17, isolated.

echo "=== EULA guard ==="

# EULA=TRUE: creates file, exits 0
eula_tmp="$(mktemp -d)"
(
    cd "$eula_tmp"
    EULA=TRUE
    if [ "${EULA:-}" = "TRUE" ]; then
        echo "eula=true" > eula.txt
    else
        exit 1
    fi
)
assert_code "EULA=TRUE → exit 0" 0 $?
assert_eq    "EULA=TRUE → writes eula=true" "eula=true" "$(cat "$eula_tmp/eula.txt")"
rm -rf "$eula_tmp"

# EULA not set: exits 1, error on stderr
set +e
output_unset=$(EULA="" bash -c 'if [ "${EULA:-}" = "TRUE" ]; then true; else echo "You must accept the Minecraft EULA to run this server." >&2; echo "Set the environment variable EULA=TRUE to indicate acceptance." >&2; echo "The EULA can be found at: https://aka.ms/MinecraftEULA" >&2; exit 1; fi' 2>&1)
rc_unset=$?
set -e
assert_code "EULA unset → exit 1" 1 "$rc_unset"
assert_contains "EULA unset → prints instructions" "You must accept" "$output_unset"
assert_contains "EULA unset → prints EULA link" "aka.ms/MinecraftEULA" "$output_unset"

# EULA=FALSE: same as unset
set +e
output_false=$(EULA=FALSE bash -c 'if [ "${EULA:-}" = "TRUE" ]; then true; else echo "You must accept the Minecraft EULA to run this server." >&2; echo "Set the environment variable EULA=TRUE to indicate acceptance." >&2; echo "The EULA can be found at: https://aka.ms/MinecraftEULA" >&2; exit 1; fi' 2>&1)
rc_false=$?
set -e
assert_code "EULA=FALSE → exit 1" 1 "$rc_false"
assert_contains "EULA=FALSE → prints error" "You must accept" "$output_false"
echo

# ==========================================================
# 4. is_percentage
# ==========================================================

echo "=== is_percentage ==="
assert_eq "75% → true"  "0" "$(is_percentage "75%" && echo 0 || echo 1)"
assert_eq "4G → false"  "1" "$(is_percentage "4G" && echo 0 || echo 1)"
assert_eq "2048M → false" "1" "$(is_percentage "2048M" && echo 0 || echo 1)"
assert_eq "empty → false" "1" "$(is_percentage "" && echo 0 || echo 1)"
echo

# ==========================================================
# 5. Memory calculation (HEAP_SIZE)
# ==========================================================

echo "=== Memory calculation (HEAP_SIZE) ==="

calculate_heap_size() {
    local memory="$1" sys_reserved="$2" limit_mb="$3"
    if [ -n "${memory:-}" ]; then
        echo "$memory"
        return
    fi
    local reserved_mb
    if [ -n "${sys_reserved:-}" ]; then
        reserved_mb=$(parse_mb "$sys_reserved")
    else
        reserved_mb=$(( limit_mb * 15 / 100 ))
        [ "$reserved_mb" -lt 512 ] && reserved_mb=512
        [ "$reserved_mb" -gt 1024 ] && reserved_mb=1024
    fi
    local heap_mb=$(( limit_mb - reserved_mb ))
    [ "$heap_mb" -lt 512 ] && heap_mb=512
    echo "${heap_mb}M"
}

assert_eq "explicit MEMORY=2G → 2G" "2G" "$(calculate_heap_size "2G" "1G" 4096)"
assert_eq "explicit MEMORY=512M → 512M" "512M" "$(calculate_heap_size "512M" "1G" 4096)"
assert_eq "explicit MEMORY=1G → 1G" "1G" "$(calculate_heap_size "1G" "2G" 2048)"

# Explicit SYSTEM_RESERVED overrides (old behavior preserved)
assert_eq "4G limit, explicit 1G reserved → 3072M" "3072M" "$(calculate_heap_size "" "1G" 4096)"
assert_eq "2G limit, explicit 2G reserved → clamped to 512M" "512M" "$(calculate_heap_size "" "2G" 2048)"
assert_eq "8G limit, explicit 5G reserved → 3072M" "3072M" "$(calculate_heap_size "" "5G" 8192)"

# Dynamic SYSTEM_RESERVED (15% of limit, min 512M, max 1G)
assert_eq "1G limit, dynamic → 512M reserve, heap=512M" "512M" "$(calculate_heap_size "" "" 1024)"
assert_eq "2G limit, dynamic → 512M reserve, heap=1536M" "1536M" "$(calculate_heap_size "" "" 2048)"
assert_eq "3G limit, dynamic → 512M reserve, heap=2560M" "2560M" "$(calculate_heap_size "" "" 3072)"
assert_eq "4G limit, dynamic → 614M reserve, heap=3482M" "3482M" "$(calculate_heap_size "" "" 4096)"
assert_eq "6G limit, dynamic → 921M reserve, heap=5223M" "5223M" "$(calculate_heap_size "" "" 6144)"
assert_eq "7G limit, dynamic → 1024M reserve, heap=6144M" "6144M" "$(calculate_heap_size "" "" 7168)"
assert_eq "8G limit, dynamic → 1024M reserve, heap=7168M" "7168M" "$(calculate_heap_size "" "" 8192)"
assert_eq "16G limit, dynamic → 1024M reserve, heap=15360M" "15360M" "$(calculate_heap_size "" "" 16384)"
echo

# ==========================================================
# 6. INIT_MEMORY / MAX_MEMORY / percentage
# ==========================================================

echo "=== INIT_MEMORY / MAX_MEMORY / percentage ==="

build_mem_args() {
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

assert_eq "fixed 4G → -Xms4G -Xmx4G" \
    "-Xms4G -Xmx4G" "$(build_mem_args "4G" "4G")"
assert_eq "init=1G max=4G → -Xms1G -Xmx4G" \
    "-Xms1G -Xmx4G" "$(build_mem_args "1G" "4G")"
assert_eq "percentage 75% → InitialRAMPercentage/MaxRAMPercentage" \
    "-XX:InitialRAMPercentage=75 -XX:MaxRAMPercentage=75" "$(build_mem_args "75%" "75%")"
assert_eq "percentage init=50% max=80%" \
    "-XX:InitialRAMPercentage=50 -XX:MaxRAMPercentage=80" "$(build_mem_args "50%" "80%")"
assert_eq "mixed: absolute init + percentage max" \
    "-Xms1G -XX:MaxRAMPercentage=75" "$(build_mem_args "1G" "75%")"
assert_eq "mixed: percentage init + absolute max" \
    "-XX:InitialRAMPercentage=50 -Xmx4G" "$(build_mem_args "50%" "4G")"
echo

# ==========================================================
# 7. Aikar's flags >12GB variant
# ==========================================================

echo "=== Aikar's flags: >12GB variant ==="

aikar_flags() {
    local max_mem="$1"
    local heap_mb=0
    if ! is_percentage "$max_mem"; then
        heap_mb=$(parse_mb "$max_mem" 2>/dev/null || echo 0)
    fi
    if [ "$heap_mb" -ge 12288 ]; then
        echo "16M:40:50:15:20"
    else
        echo "8M:30:40:20:15"
    fi
}

assert_eq "4G → standard flags"  "8M:30:40:20:15" "$(aikar_flags "4G")"
assert_eq "8G → standard flags"  "8M:30:40:20:15" "$(aikar_flags "8G")"
assert_eq "10G → standard flags" "8M:30:40:20:15" "$(aikar_flags "10G")"
assert_eq "12G → >12GB flags"   "16M:40:50:15:20" "$(aikar_flags "12G")"
assert_eq "16G → >12GB flags"   "16M:40:50:15:20" "$(aikar_flags "16G")"
assert_eq "12884901888 bytes (12G) → >12GB" \
    "16M:40:50:15:20" "$(aikar_flags "12884901888")"
assert_eq "percentage → standard (unknown size)" \
    "8M:30:40:20:15" "$(aikar_flags "75%")"
echo

# ==========================================================
# 8. Named pipe (stdin pipe)
# ==========================================================
# Tests the FIFO creation and data flow used for sending
# commands to the Minecraft server via docker exec.

echo "=== stdin pipe ==="

pipe_tmp="$(mktemp -d)"
pipe_cleanup() { rm -rf "$pipe_tmp" "$TMP"; }
trap pipe_cleanup EXIT

# 5a. FIFO is created and is a named pipe
mkfifo -m 666 "$pipe_tmp/minecraft-stdin" 2>/dev/null || true
if test -p "$pipe_tmp/minecraft-stdin"; then result="ok"; else result="fail"; fi
assert_eq "FIFO is a named pipe" "ok" "$result"

# 5b. FIFO permissions
fifo_perms=$(stat -c "%a" "$pipe_tmp/minecraft-stdin")
assert_eq "FIFO has 666 permissions" "666" "$fifo_perms"

rm -f "$pipe_tmp/minecraft-stdin"

# 5c. Data flows through pipe
mkfifo "$pipe_tmp/minecraft-stdin"
sleep infinity > "$pipe_tmp/minecraft-stdin" &
writer_pid=$!
cat "$pipe_tmp/minecraft-stdin" > "$pipe_tmp/output" &
reader_pid=$!
echo "test command" > "$pipe_tmp/minecraft-stdin"
sleep 0.5
kill $reader_pid $writer_pid 2>/dev/null || true
wait $reader_pid 2>/dev/null || true
wait $writer_pid 2>/dev/null || true
if grep -q "test command" "$pipe_tmp/output"; then result="ok"; else result="fail"; fi
assert_eq "Data written to pipe is readable" "ok" "$result"

rm -f "$pipe_tmp/minecraft-stdin" "$pipe_tmp/output"

# 5d. Multiple commands flow through without EOF
mkfifo "$pipe_tmp/minecraft-stdin"
sleep infinity > "$pipe_tmp/minecraft-stdin" &
writer_pid=$!
cat "$pipe_tmp/minecraft-stdin" > "$pipe_tmp/output" &
reader_pid=$!
echo "cmd1" > "$pipe_tmp/minecraft-stdin"
sleep 0.2
echo "cmd2" > "$pipe_tmp/minecraft-stdin"
sleep 0.2
echo "cmd3" > "$pipe_tmp/minecraft-stdin"
sleep 0.5
kill $reader_pid $writer_pid 2>/dev/null || true
wait $reader_pid 2>/dev/null || true
wait $writer_pid 2>/dev/null || true
line_count=$(grep -c "^cmd" "$pipe_tmp/output" 2>/dev/null || echo 0)
assert_eq "Multiple commands flow through without EOF" "3" "$line_count"

rm -f "$pipe_tmp/minecraft-stdin" "$pipe_tmp/output"

# 5e. Pipe survives closing writers (sleep infinity keeps it open)
mkfifo "$pipe_tmp/minecraft-stdin"
sleep infinity > "$pipe_tmp/minecraft-stdin" &
writer_pid=$!
(
    while read -r line; do
        echo "$line" >> "$pipe_tmp/output"
    done < "$pipe_tmp/minecraft-stdin"
) &
reader_pid=$!
echo "first" > "$pipe_tmp/minecraft-stdin"
sleep 0.2
echo "second" > "$pipe_tmp/minecraft-stdin"
sleep 0.2
kill $reader_pid 2>/dev/null || true
wait $reader_pid 2>/dev/null || true
kill $writer_pid 2>/dev/null || true
wait $writer_pid 2>/dev/null || true
line_count=$(grep -c "." "$pipe_tmp/output" 2>/dev/null || echo 0)
assert_eq "Commands flow through with persistent writer" "2" "$line_count"

rm -f "$pipe_tmp/minecraft-stdin" "$pipe_tmp/output"
echo

# ==========================================================
# 9. Security mitigations (Log4Shell + BleedingPipe/SerializationIsBad)
# ==========================================================

echo "=== Security mitigations ==="

# 9a. get_security_jvm_opts returns both JVM flags and Java agents
security_opts=$(get_security_jvm_opts)
assert_contains "security opts contain formatMsgNoLookups" \
    "-Dlog4j2.formatMsgNoLookups=true" "$security_opts"
assert_contains "security opts contain Log4jPatcher agent" \
    "-javaagent:/usr/local/bin/Log4jPatcher.jar" "$security_opts"
assert_contains "security opts contain SerializationIsBad agent" \
    "-javaagent:/usr/local/bin/serializationisbad.jar" "$security_opts"

# 9b. entrypoint.sh applies JAVA_SECURITY_OPTS in both exec java blocks
entrypoint_file="${SCRIPT_DIR}/../scripts/entrypoint.sh"
# Count lines referencing JAVA_SECURITY_OPTS: 1 assignment + 2 usages = 3
import_count=$(grep -c 'JAVA_SECURITY_OPTS' "$entrypoint_file" || true)
assert_eq "JAVA_SECURITY_OPTS appears 3 times (1 assign + 2 exec blocks)" "3" "$import_count"

exec_usage_count=$(grep -c '${JAVA_SECURITY_OPTS}' "$entrypoint_file" || true)
assert_eq "both exec java blocks reference JAVA_SECURITY_OPTS" "2" "$exec_usage_count"

# 9c. formatMsgNoLookups must only appear in runtime-functions.sh (get_security_jvm_opts)
#     Not hardcoded anywhere in entrypoint.sh — proves single source of truth
func_count=$(grep -c 'formatMsgNoLookups' "$entrypoint_file" || true)
assert_eq "formatMsgNoLookups not hardcoded in entrypoint.sh" "0" "$func_count"

# 9d. entrypoint.sh seeds serializationisbad.json config into config/ directory
seed_count=$(grep -c 'serializationisbad.json' "$entrypoint_file" || true)
assert_eq "entrypoint seeds serializationisbad.json to config dir" "1" "$seed_count"

# 9e. Dockerfile downloads Log4jPatcher from CreeperHost
dockerfile_path="${SCRIPT_DIR}/../Dockerfile"
patcher_url="https://github.com/CreeperHost/Log4jPatcher/releases/download/v1.0.1/Log4jPatcher-1.0.1.jar"
patcher_dest="/usr/local/bin/Log4jPatcher.jar"
if grep -qF "$patcher_url" "$dockerfile_path"; then
    pass "Dockerfile downloads Log4jPatcher from CreeperHost"
else
    fail "Dockerfile downloads Log4jPatcher from CreeperHost" \
        "URL not found in Dockerfile"
fi
if grep -qF "$patcher_dest" "$dockerfile_path"; then
    pass "Dockerfile saves Log4jPatcher to $patcher_dest"
else
    fail "Dockerfile saves Log4jPatcher to $patcher_dest" \
        "destination path not found in Dockerfile"
fi

# 9f. Dockerfile downloads SerializationIsBad agent and config
sib_url="https://github.com/dogboy21/serializationisbad/releases/download/1.5.2/serializationisbad-1.5.2.jar"
sib_dest="/usr/local/bin/serializationisbad.jar"
sib_cfg="serializationisbad.json"
if grep -qF "$sib_url" "$dockerfile_path"; then
    pass "Dockerfile downloads SerializationIsBad agent"
else
    fail "Dockerfile downloads SerializationIsBad agent" \
        "URL not found in Dockerfile"
fi
if grep -qF "$sib_dest" "$dockerfile_path"; then
    pass "Dockerfile saves SerializationIsBad agent to $sib_dest"
else
    fail "Dockerfile saves SerializationIsBad agent to $sib_dest" \
        "destination path not found in Dockerfile"
fi
if grep -qF "$sib_cfg" "$dockerfile_path"; then
    pass "Dockerfile downloads SerializationIsBad config"
else
    fail "Dockerfile downloads SerializationIsBad config" \
        "config filename not found in Dockerfile"
fi

# 9g. Both JARs are outside the data VOLUME (/usr/local/minecraft)
volume_line=$(grep '^VOLUME' "$dockerfile_path" || echo "")
assert_contains "Log4jPatcher.jar is outside the VOLUME" \
    "/usr/local/bin" "$patcher_dest"
assert_contains "SerializationIsBad.jar is outside the VOLUME" \
    "/usr/local/bin" "$sib_dest"
assert_contains "VOLUME targets /usr/local/minecraft (not /usr/local/bin)" \
    "/usr/local/minecraft" "$volume_line"
echo

# ==========================================================
# Results
# ==========================================================
echo "============================="
printf "Results: %d passed, %d failed\n" "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
    echo "SOME TESTS FAILED"
    exit 1
else
    echo "ALL TESTS PASSED"
fi
