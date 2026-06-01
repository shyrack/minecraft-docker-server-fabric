#!/bin/bash
set -euo pipefail

provider_resolve_version() {
    if [ "${MINECRAFT_VERSION}" != "latest" ]; then
        return 0
    fi
    MINECRAFT_VERSION=$(wget -T 30 -q -O - "https://launchermeta.mojang.com/mc/game/version_manifest.json" | \
        jq -r '.latest.release')
}

provider_download_server() {
    if [ -f spigot.jar ]; then
        return 0
    fi
    echo "Downloading Spigot server JAR..."
    for i in 1 2 3; do
        wget -T 30 -O spigot.jar \
            "https://download.getbukkit.org/spigot/spigot-${MINECRAFT_VERSION}.jar" \
            && break
        echo "Download attempt $i failed, retrying..."
        sleep 5
    done
    if [ ! -s spigot.jar ]; then
        echo "ERROR: Failed to download Spigot JAR after 3 attempts" >&2
        return 1
    fi
    if ! head -c 2 spigot.jar | grep -q 'PK'; then
        echo "ERROR: Downloaded file does not appear to be a valid ZIP/JAR" >&2
        return 1
    fi
}

provider_get_jar() {
    echo "spigot.jar"
}

provider_get_launch_args() {
    echo "nogui"
}
