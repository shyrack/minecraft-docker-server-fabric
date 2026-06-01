#!/bin/bash
set -euo pipefail

provider_resolve_version() {
    if [ "${MINECRAFT_VERSION}" = "latest" ]; then
        MINECRAFT_VERSION=$(wget -T 30 -q -O - "https://meta.fabricmc.net/v2/versions/game" | \
            jq -r 'map(select(.stable == true)) | first | .version')
    fi
    if [ "${FABRIC_LOADER:-latest}" = "latest" ]; then
        FABRIC_LOADER=$(wget -T 30 -q -O - "https://meta.fabricmc.net/v2/versions/loader/${MINECRAFT_VERSION}" | \
            jq -r 'map(select(.loader.stable == true)) | first | .loader.version')
    fi
    if [ "${FABRIC_INSTALLER:-latest}" = "latest" ]; then
        FABRIC_INSTALLER=$(wget -T 30 -q -O - "https://meta.fabricmc.net/v2/versions/installer" | \
            jq -r 'map(select(.stable == true)) | first | .version')
    fi
}

provider_download_server() {
    if [ -f fabric-server.jar ]; then
        return 0
    fi
    echo "Downloading fabric-server.jar..."
    for i in 1 2 3; do
        wget -T 30 -O fabric-server.jar \
            "https://meta.fabricmc.net/v2/versions/loader/${MINECRAFT_VERSION}/${FABRIC_LOADER}/${FABRIC_INSTALLER}/server/jar" \
            && break
        echo "Download attempt $i failed, retrying..."
        sleep 5
    done
    if [ ! -s fabric-server.jar ]; then
        echo "ERROR: Failed to download fabric-server.jar after 3 attempts" >&2
        return 1
    fi
    if ! head -c 2 fabric-server.jar | grep -q 'PK'; then
        echo "ERROR: Downloaded file does not appear to be a valid ZIP/JAR" >&2
        return 1
    fi
}

provider_get_jar() {
    echo "fabric-server.jar"
}

provider_get_launch_args() {
    echo "nogui"
}
