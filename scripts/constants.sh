#!/bin/bash
set -euo pipefail

# This file is sourced by runtime-functions.sh. Variables below are consumed by
# runtime-functions.sh, entrypoint.sh, and provider scripts.

# shellcheck disable=SC2034
readonly MINECRAFT_PORT=25565
# shellcheck disable=SC2034
readonly DEFAULT_SERVER_TYPE="fabric"
# shellcheck disable=SC2034
readonly DEFAULT_VERSION_SENTINEL="latest"

# shellcheck disable=SC2034
readonly MIN_RESERVED_MB=512
# shellcheck disable=SC2034
readonly MAX_RESERVED_MB=1024
# shellcheck disable=SC2034
readonly DEFAULT_RESERVED_PCT=15
# shellcheck disable=SC2034
readonly MIN_HEAP_MB=512
# shellcheck disable=SC2034
readonly LARGE_HEAP_THRESHOLD_MB=12288

# shellcheck disable=SC2034
readonly WGET_TIMEOUT=30
# shellcheck disable=SC2034
readonly WGET_TIMEOUT_LARGE=60
# shellcheck disable=SC2034
readonly DOWNLOAD_RETRIES=3
# shellcheck disable=SC2034
readonly DOWNLOAD_RETRY_DELAY=5

# shellcheck disable=SC2034
readonly HEALTHCHECK_INTERVAL="30s"
# shellcheck disable=SC2034
readonly HEALTHCHECK_TIMEOUT="10s"
# shellcheck disable=SC2034
readonly HEALTHCHECK_START_PERIOD="300s"
# shellcheck disable=SC2034
readonly HEALTHCHECK_RETRIES=3
