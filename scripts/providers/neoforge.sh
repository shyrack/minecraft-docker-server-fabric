#!/bin/bash
set -euo pipefail

provider_resolve_version() {
    if [ "${NEOFORGE_VERSION:-${DEFAULT_VERSION_SENTINEL}}" != "${DEFAULT_VERSION_SENTINEL}" ]; then
        if [ "${MINECRAFT_VERSION}" = "${DEFAULT_VERSION_SENTINEL}" ]; then
            MINECRAFT_VERSION=$(echo "$NEOFORGE_VERSION" | cut -d'-' -f1)
        fi
        return 0
    fi

    local metadata
    metadata=$(wget -T "${WGET_TIMEOUT}" -q -O - "https://maven.neoforged.net/releases/net/neoforged/neoforge/maven-metadata.xml")
    if [ "${MINECRAFT_VERSION}" != "${DEFAULT_VERSION_SENTINEL}" ]; then
        NEOFORGE_VERSION=$(echo "$metadata" | grep -o '<version>[^<]*</version>' | \
            sed 's/<[^>]*>//g' | grep "^${MINECRAFT_VERSION}-" | sort -V | tail -1)
        if [ -z "$NEOFORGE_VERSION" ]; then
            echo "ERROR: No NeoForge version found for Minecraft ${MINECRAFT_VERSION}" >&2
            return 1
        fi
    else
        NEOFORGE_VERSION=$(echo "$metadata" | sed -n 's/.*<release>\([^<]*\).*/\1/p')
        if [ -z "$NEOFORGE_VERSION" ]; then
            echo "ERROR: Could not resolve latest NeoForge version" >&2
            return 1
        fi
        MINECRAFT_VERSION=$(echo "$NEOFORGE_VERSION" | cut -d'-' -f1)
    fi
}

provider_download_server() {
    local installer="neoforge-${NEOFORGE_VERSION}-installer.jar"
    local args_file="libraries/net/neoforged/neoforge/${NEOFORGE_VERSION}/unix_args.txt"

    if [ -f "$args_file" ] && [ -f run.sh ]; then
        return 0
    fi

    download_and_verify_large \
        "https://maven.neoforged.net/releases/net/neoforged/neoforge/${NEOFORGE_VERSION}/${installer}" \
        "$installer" \
        "NeoForge installer ${NEOFORGE_VERSION}"

    echo "Running NeoForge installer (this may take a moment)..."
    java -jar "$installer" --installServer || {
        echo "ERROR: NeoForge installer failed" >&2
        return 1
    }
    rm -f "$installer" "${installer}.log"

    if [ ! -f "$args_file" ]; then
        echo "ERROR: NeoForge installation did not produce expected files" >&2
        return 1
    fi
}

provider_get_jar() {
    echo ""
}

provider_get_launch_args() {
    echo "@libraries/net/neoforged/neoforge/${NEOFORGE_VERSION}/unix_args.txt nogui"
}
