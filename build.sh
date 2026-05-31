#!/usr/bin/env bash
set -euo pipefail

echo "Checking latest stable Fabric + Minecraft versions..."

MINECRAFT=$(curl -fsSL https://meta.fabricmc.net/v2/versions/game | \
  jq -r 'first(.[] | select(.stable == true)) | .version')

LOADER=$(curl -fsSL "https://meta.fabricmc.net/v2/versions/loader/${MINECRAFT}" | \
  jq -r 'first(.[] | select(.loader.stable == true)) | .loader.version')

INSTALLER="${INSTALLER_VERSION:-1.1.1}"

echo "  Minecraft:        ${MINECRAFT}"
echo "  Fabric Loader:    ${LOADER}"
echo "  Fabric Installer: ${INSTALLER}"

TAG_BASE="${IMAGE_NAME:-minecraft-fabric}"
VERSION_ID="${MINECRAFT}-fabric-${LOADER}"

exec docker build \
  --build-arg "MINECRAFT_VERSION=${MINECRAFT}" \
  --build-arg "FABRIC_LOADER=${LOADER}" \
  --build-arg "INSTALLER_VERSION=${INSTALLER}" \
  -t "${TAG_BASE}:${VERSION_ID}" \
  -t "${TAG_BASE}:latest" \
  "${@}" \
  .
