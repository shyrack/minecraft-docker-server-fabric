#!/usr/bin/env bash
# Resolve latest stable Minecraft + Fabric Loader versions from meta.fabricmc.net
#
# Usage:
#   source scripts/version-resolve.sh    # exports MINECRAFT_VERSION, FABRIC_LOADER, INSTALLER_VERSION
#   bash scripts/version-resolve.sh      # prints key=value lines for CI
#
# Override DEFAULT_FABRIC_INSTALLER_VERSION to change the default installer version.
set -euo pipefail

DEFAULT_FABRIC_INSTALLER_VERSION="${DEFAULT_FABRIC_INSTALLER_VERSION:-1.1.1}"

MINECRAFT_VERSION=$(curl -fsSL https://meta.fabricmc.net/v2/versions/game | \
    jq -r 'first(.[] | select(.stable == true)) | .version')

FABRIC_LOADER=$(curl -fsSL "https://meta.fabricmc.net/v2/versions/loader/${MINECRAFT_VERSION}" | \
    jq -r 'first(.[] | select(.loader.stable == true)) | .loader.version')

INSTALLER_VERSION="$DEFAULT_FABRIC_INSTALLER_VERSION"

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    echo "MINECRAFT_VERSION=${MINECRAFT_VERSION}"
    echo "FABRIC_LOADER=${FABRIC_LOADER}"
    echo "INSTALLER_VERSION=${INSTALLER_VERSION}"
fi
