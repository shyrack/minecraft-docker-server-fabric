#!/bin/bash
set -euo pipefail

provider_resolve_version() {
    if [ "${MINECRAFT_VERSION}" = "${DEFAULT_VERSION_SENTINEL}" ]; then
        MINECRAFT_VERSION=$(wget -T "${WGET_TIMEOUT}" -q -O - "https://meta.fabricmc.net/v2/versions/game" | \
            jq -r 'map(select(.stable == true)) | first | .version')
    fi
    if [ "${FABRIC_LOADER:-${DEFAULT_VERSION_SENTINEL}}" = "${DEFAULT_VERSION_SENTINEL}" ]; then
        FABRIC_LOADER=$(wget -T "${WGET_TIMEOUT}" -q -O - "https://meta.fabricmc.net/v2/versions/loader/${MINECRAFT_VERSION}" | \
            jq -r 'map(select(.loader.stable == true)) | first | .loader.version')
    fi
    if [ "${FABRIC_INSTALLER:-${DEFAULT_VERSION_SENTINEL}}" = "${DEFAULT_VERSION_SENTINEL}" ]; then
        FABRIC_INSTALLER=$(wget -T "${WGET_TIMEOUT}" -q -O - "https://meta.fabricmc.net/v2/versions/installer" | \
            jq -r 'map(select(.stable == true)) | first | .version')
    fi
}

provider_download_server() {
    if [ -f server.jar ]; then
        return 0
    fi
    download_and_verify \
        "https://meta.fabricmc.net/v2/versions/loader/${MINECRAFT_VERSION}/${FABRIC_LOADER}/${FABRIC_INSTALLER}/server/jar" \
        "server.jar" \
        "Fabric server JAR"
}

provider_get_jar() {
    echo "server.jar"
}

provider_get_launch_args() {
    echo "nogui"
}
