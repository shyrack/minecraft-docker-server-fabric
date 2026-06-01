#!/usr/bin/env bash
# Resolve latest stable Minecraft version from Mojang's launchermeta API.
#
# Usage:
#   source scripts/version-resolve.sh    # exports MINECRAFT_VERSION
#   bash scripts/version-resolve.sh      # prints key=value lines for CI
set -euo pipefail

MINECRAFT_VERSION=$(curl -fsSL "https://launchermeta.mojang.com/mc/game/version_manifest.json" | \
    jq -r '.latest.release')

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    echo "MINECRAFT_VERSION=${MINECRAFT_VERSION}"
fi
