#!/bin/bash
set -euo pipefail

provider_resolve_version() {
    if [ "${MINECRAFT_VERSION}" != "latest" ]; then
        return 0
    fi
    local manifest
    manifest=$(wget -T 30 -q -O - "https://launchermeta.mojang.com/mc/game/version_manifest.json")
    MINECRAFT_VERSION=$(echo "$manifest" | jq -r '.latest.release')
}

provider_download_server() {
    if [ -f server.jar ]; then
        return 0
    fi
    echo "Downloading Minecraft server JAR..."
    local manifest version_url download_url
    manifest=$(wget -T 30 -q -O - "https://launchermeta.mojang.com/mc/game/version_manifest.json")
    version_url=$(echo "$manifest" | jq -r --arg v "$MINECRAFT_VERSION" '.versions[] | select(.id == $v) | .url')
    if [ -z "$version_url" ]; then
        echo "ERROR: Could not find download URL for Minecraft ${MINECRAFT_VERSION}" >&2
        return 1
    fi
    download_url=$(wget -T 30 -q -O - "$version_url" | jq -r '.downloads.server.url')
    if [ -z "$download_url" ]; then
        echo "ERROR: Could not find server download URL for Minecraft ${MINECRAFT_VERSION}" >&2
        return 1
    fi
    for i in 1 2 3; do
        wget -T 60 -O server.jar "$download_url" && break
        echo "Download attempt $i failed, retrying..."
        sleep 5
    done
    if [ ! -s server.jar ]; then
        echo "ERROR: Failed to download server.jar after 3 attempts" >&2
        return 1
    fi
    if ! head -c 2 server.jar | grep -q 'PK'; then
        echo "ERROR: Downloaded file does not appear to be a valid ZIP/JAR" >&2
        return 1
    fi
}

provider_get_jar() {
    echo "server.jar"
}

provider_get_launch_args() {
    echo "nogui"
}
