#!/bin/bash
set -euo pipefail

provider_resolve_version() {
    if [ "${MINECRAFT_VERSION}" = "${DEFAULT_VERSION_SENTINEL}" ]; then
        MINECRAFT_VERSION=$(wget -T "${WGET_TIMEOUT}" -q -O - "https://api.papermc.io/v2/projects/paper" | \
            jq -r '.versions[-1]')
    fi
    if [ "${PAPER_BUILD:-${DEFAULT_VERSION_SENTINEL}}" = "${DEFAULT_VERSION_SENTINEL}" ]; then
        PAPER_BUILD=$(wget -T "${WGET_TIMEOUT}" -q -O - "https://api.papermc.io/v2/projects/paper/versions/${MINECRAFT_VERSION}/builds" | \
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
    download_and_verify \
        "https://api.papermc.io/v2/projects/paper/versions/${MINECRAFT_VERSION}/builds/${PAPER_BUILD}/downloads/${jar_name}" \
        "paper.jar" \
        "Paper server JAR (build ${PAPER_BUILD})"
}

provider_get_jar() {
    echo "paper.jar"
}

provider_get_launch_args() {
    echo "nogui"
}
