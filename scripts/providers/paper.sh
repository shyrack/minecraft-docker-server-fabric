#!/bin/bash
set -euo pipefail

provider_resolve_version() {
    if [ "${MINECRAFT_VERSION}" = "latest" ]; then
        MINECRAFT_VERSION=$(wget -T 30 -q -O - "https://api.papermc.io/v2/projects/paper" | \
            jq -r '.versions[-1]')
    fi
    if [ "${PAPER_BUILD:-latest}" = "latest" ]; then
        PAPER_BUILD=$(wget -T 30 -q -O - "https://api.papermc.io/v2/projects/paper/versions/${MINECRAFT_VERSION}/builds" | \
            jq -r '.builds[-1].build')
        if [ -z "$PAPER_BUILD" ] || [ "$PAPER_BUILD" = "null" ]; then
            echo "ERROR: No builds found for Paper ${MINECRAFT_VERSION}" >&2
            return 1
        fi
    fi
}

provider_download_server() {
    local jar_name="paper-${MINECRAFT_VERSION}-${PAPER_BUILD}.jar"
    if [ -f "$jar_name" ]; then
        return 0
    fi
    if [ -f paper.jar ]; then
        return 0
    fi
    echo "Downloading Paper server JAR (build ${PAPER_BUILD})..."
    for i in 1 2 3; do
        wget -T 30 -O paper.jar \
            "https://api.papermc.io/v2/projects/paper/versions/${MINECRAFT_VERSION}/builds/${PAPER_BUILD}/downloads/${jar_name}" \
            && break
        echo "Download attempt $i failed, retrying..."
        sleep 5
    done
    if [ ! -s paper.jar ]; then
        echo "ERROR: Failed to download Paper server JAR after 3 attempts" >&2
        return 1
    fi
    if ! head -c 2 paper.jar | grep -q 'PK'; then
        echo "ERROR: Downloaded file does not appear to be a valid ZIP/JAR" >&2
        return 1
    fi
}

provider_get_jar() {
    echo "paper.jar"
}

provider_get_launch_args() {
    echo "nogui"
}
