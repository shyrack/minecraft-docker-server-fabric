#!/usr/bin/env bash
set -euo pipefail

echo "Checking latest stable Fabric + Minecraft versions..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/scripts/version-resolve.sh"

echo "  Minecraft:        ${MINECRAFT_VERSION}"
echo "  Fabric Loader:    ${FABRIC_LOADER}"
echo "  Fabric Installer: ${INSTALLER_VERSION}"

TAG_BASE="${IMAGE_NAME:-minecraft-fabric}"
VERSION_ID="${MINECRAFT_VERSION}-fabric-${FABRIC_LOADER}"

exec docker build \
  --build-arg "MINECRAFT_VERSION=${MINECRAFT_VERSION}" \
  --build-arg "FABRIC_LOADER=${FABRIC_LOADER}" \
  --build-arg "INSTALLER_VERSION=${INSTALLER_VERSION}" \
  -t "${TAG_BASE}:${VERSION_ID}" \
  -t "${TAG_BASE}:latest" \
  "${@}" \
  .
