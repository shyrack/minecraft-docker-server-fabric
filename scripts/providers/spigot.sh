#!/bin/bash
set -euo pipefail

provider_resolve_version() {
    if [ "${MINECRAFT_VERSION}" != "${DEFAULT_VERSION_SENTINEL}" ]; then
        return 0
    fi
    MINECRAFT_VERSION=$(wget -T "${WGET_TIMEOUT}" -q -O - "https://launchermeta.mojang.com/mc/game/version_manifest.json" | \
        jq -r '.latest.release')
}

provider_download_server() {
    if [ -f spigot.jar ]; then
        return 0
    fi
    download_and_verify \
        "https://download.getbukkit.org/spigot/spigot-${MINECRAFT_VERSION}.jar" \
        "spigot.jar" \
        "Spigot server JAR"
}

provider_get_jar() {
    echo "spigot.jar"
}

provider_get_launch_args() {
    echo "nogui"
}
