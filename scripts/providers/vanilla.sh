#!/bin/bash
set -euo pipefail

provider_resolve_version() {
    if [ "${MINECRAFT_VERSION}" != "${DEFAULT_VERSION_SENTINEL}" ]; then
        return 0
    fi
    local manifest
    manifest=$(wget -T "${WGET_TIMEOUT}" -q -O - "https://launchermeta.mojang.com/mc/game/version_manifest.json")
    MINECRAFT_VERSION=$(echo "$manifest" | jq -r '.latest.release')
}

provider_download_server() {
    if [ -f server.jar ]; then
        return 0
    fi
    local manifest version_url download_url
    manifest=$(wget -T "${WGET_TIMEOUT}" -q -O - "https://launchermeta.mojang.com/mc/game/version_manifest.json")
    version_url=$(echo "$manifest" | jq -r --arg v "$MINECRAFT_VERSION" '.versions[] | select(.id == $v) | .url')
    if [ -z "$version_url" ]; then
        echo "ERROR: Could not find download URL for Minecraft ${MINECRAFT_VERSION}" >&2
        return 1
    fi
    download_url=$(wget -T "${WGET_TIMEOUT}" -q -O - "$version_url" | jq -r '.downloads.server.url')
    if [ -z "$download_url" ]; then
        echo "ERROR: Could not find server download URL for Minecraft ${MINECRAFT_VERSION}" >&2
        return 1
    fi
    download_and_verify_large "$download_url" "server.jar" "Minecraft server JAR"
}

provider_get_jar() {
    echo "server.jar"
}

provider_get_launch_args() {
    echo "nogui"
}
