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
# 4. Memory calculation
# ==========================================================
# Tests the main memory logic from entrypoint.sh (lines 39-48)

echo "=== Memory calculation ==="

# When MEMORY is explicitly set, it overrides everything
calculate_heap() {
    # $1 = MEMORY env value (or empty)
    # $2 = SYSTEM_RESERVED env value (or empty, defaults to 1G)
    # $3 = cgroup/meminfo limit in MB
    # Uses the exact same parse_mb and logic as entrypoint.sh
    local memory="$1" sys_reserved="$2" limit_mb="$3"

    if [ -n "${memory:-}" ]; then
        echo "$memory"
        return
    fi

    sys_reserved="${sys_reserved:-1G}"
    local reserved_mb
    reserved_mb=$(parse_mb "$sys_reserved")
    local heap_mb=$(( limit_mb - reserved_mb ))
    [ "$heap_mb" -lt 512 ] && heap_mb=512
    echo "${heap_mb}M"
}

assert_eq "explicit MEMORY=2G → 2G" "2G" "$(calculate_heap "2G" "1G" 4096)"
assert_eq "explicit MEMORY=512M → 512M" "512M" "$(calculate_heap "512M" "1G" 4096)"
assert_eq "explicit MEMORY=1G → 1G" "1G" "$(calculate_heap "1G" "2G" 2048)"

# Auto calculation: limit=4096 MB, reserved=1G=1024 MB → 3072M
assert_eq "4G limit, 1G reserved → 3072M" "3072M" "$(calculate_heap "" "1G" 4096)"

# Auto calculation: limit=2048 MB, reserved=2G=2048 MB → would be 0, clamped to 512M
assert_eq "2G limit, 2G reserved → clamped to 512M" "512M" "$(calculate_heap "" "2G" 2048)"

# Auto calculation: limit=1200 MB, reserved=512M → 688M
assert_eq "1200M limit, 512M reserved → 688M" "688M" "$(calculate_heap "" "512M" 1200)"

# Auto calculation: default SYSTEM_RESERVED=1G, limit=3000 MB → 1976M
assert_eq "3G limit, default 1G reserved → 1976M" "1976M" "$(calculate_heap "" "" 3000)"

# Auto calculation: reserved in gigabytes with G suffix
assert_eq "8G limit, 5G reserved → 3072M" "3072M" "$(calculate_heap "" "5G" 8192)"
echo

# ==========================================================
# 5. Named pipe (stdin pipe)
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
