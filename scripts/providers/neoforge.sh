#!/bin/bash
set -euo pipefail

provider_resolve_version() {
    if [ "${NEOFORGE_VERSION:-latest}" = "latest" ]; then
        local metadata
        metadata=$(wget -T 30 -q -O - "https://maven.neoforged.net/releases/net/neoforged/neoforge/maven-metadata.xml")
        NEOFORGE_VERSION=$(echo "$metadata" | grep -oP '<release>\K[^<]+')
        if [ -z "$NEOFORGE_VERSION" ]; then
            echo "ERROR: Could not resolve latest NeoForge version" >&2
            return 1
        fi
    fi
    if [ "${MINECRAFT_VERSION}" = "latest" ]; then
        MINECRAFT_VERSION=$(echo "$NEOFORGE_VERSION" | cut -d'-' -f1)
    fi
}

provider_download_server() {
    local installer="neoforge-${NEOFORGE_VERSION}-installer.jar"
    local args_file="libraries/net/neoforged/neoforge/${NEOFORGE_VERSION}/unix_args.txt"

    if [ -f "$args_file" ] && [ -f run.sh ]; then
        return 0
    fi

    echo "Downloading NeoForge installer ${NEOFORGE_VERSION}..."
    for i in 1 2 3; do
        wget -T 60 -O "$installer" \
            "https://maven.neoforged.net/releases/net/neoforged/neoforge/${NEOFORGE_VERSION}/${installer}" \
            && break
        echo "Download attempt $i failed, retrying..."
        sleep 5
    done
    if [ ! -s "$installer" ]; then
        echo "ERROR: Failed to download NeoForge installer after 3 attempts" >&2
        return 1
    fi
    if ! head -c 2 "$installer" | grep -q 'PK'; then
        echo "ERROR: Downloaded installer does not appear to be a valid ZIP/JAR" >&2
        return 1
    fi

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
