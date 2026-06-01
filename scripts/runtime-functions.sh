#!/bin/bash
# Pure functions shared between entrypoint.sh and the test suite.
# Sourcing this file has no side effects; it only defines functions.
# Override the cgroup paths via arguments to test without real /sys access.
set -eu

parse_mb() {
    case "$1" in
        *[Gg]) echo $(( ${1%[Gg]} * 1024 )) ;;
        *[Mm]) echo "${1%[Mm]}" ;;
        *)     echo $(( $1 / 1048576 )) ;;
    esac
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
