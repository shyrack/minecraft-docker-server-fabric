#!/bin/bash
set -euo pipefail

provider_resolve_version() {
    if [ "${MINECRAFT_VERSION}" = "latest" ]; then
        MINECRAFT_VERSION=$(wget -T 30 -q -O - "https://launchermeta.mojang.com/mc/game/version_manifest.json" | \
            jq -r '.latest.release')
    fi
    if [ "${FORGE_VERSION:-latest}" = "latest" ]; then
        local promotions
        promotions=$(wget -T 30 -q -O - "https://files.minecraftforge.net/net/minecraftforge/forge/promotions_slim.json")
        FORGE_VERSION=$(echo "$promotions" | jq -r --arg mc "$MINECRAFT_VERSION" '.promos["\($mc)-recommended"] // .promos["\($mc)-latest"] // empty')
        if [ -z "$FORGE_VERSION" ]; then
            echo "ERROR: No Forge version found for Minecraft ${MINECRAFT_VERSION}" >&2
            return 1
        fi
    fi
    FORGE_COMBINED="${MINECRAFT_VERSION}-${FORGE_VERSION}"
}

provider_download_server() {
    local installer="forge-${FORGE_COMBINED}-installer.jar"
    local args_file="libraries/net/minecraftforge/forge/${FORGE_COMBINED}/unix_args.txt"

    if [ -f "$args_file" ] && [ -f run.sh ]; then
        return 0
    fi

    echo "Downloading Forge installer ${FORGE_COMBINED}..."
    for i in 1 2 3; do
        wget -T 60 -O "$installer" \
            "https://maven.minecraftforge.net/net/minecraftforge/forge/${FORGE_COMBINED}/${installer}" \
            && break
        echo "Download attempt $i failed, retrying..."
        sleep 5
    done
    if [ ! -s "$installer" ]; then
        echo "ERROR: Failed to download Forge installer after 3 attempts" >&2
        return 1
    fi
    if ! head -c 2 "$installer" | grep -q 'PK'; then
        echo "ERROR: Downloaded installer does not appear to be a valid ZIP/JAR" >&2
        return 1
    fi

    echo "Running Forge installer (this may take a moment)..."
    java -jar "$installer" --installServer || {
        echo "ERROR: Forge installer failed" >&2
        return 1
    }
    rm -f "$installer" "${installer}.log"

    if [ ! -f "$args_file" ]; then
        echo "ERROR: Forge installation did not produce expected files" >&2
        return 1
    fi
}

provider_get_jar() {
    echo ""
}

provider_get_launch_args() {
    echo "@libraries/net/minecraftforge/forge/${FORGE_COMBINED}/unix_args.txt nogui"
}
