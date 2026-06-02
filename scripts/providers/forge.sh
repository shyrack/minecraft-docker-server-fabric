#!/bin/bash
set -euo pipefail

provider_resolve_version() {
    if [ "${MINECRAFT_VERSION}" = "${DEFAULT_VERSION_SENTINEL}" ]; then
        MINECRAFT_VERSION=$(wget -T "${WGET_TIMEOUT}" -q -O - "https://launchermeta.mojang.com/mc/game/version_manifest.json" | \
            jq -r '.latest.release')
    fi
    if [ "${FORGE_VERSION:-${DEFAULT_VERSION_SENTINEL}}" = "${DEFAULT_VERSION_SENTINEL}" ]; then
        local promotions
        promotions=$(wget -T "${WGET_TIMEOUT}" -q -O - "https://files.minecraftforge.net/net/minecraftforge/forge/promotions_slim.json")
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

    download_and_verify_large \
        "https://maven.minecraftforge.net/net/minecraftforge/forge/${FORGE_COMBINED}/${installer}" \
        "$installer" \
        "Forge installer ${FORGE_COMBINED}"

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
