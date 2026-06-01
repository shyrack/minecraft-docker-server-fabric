#!/usr/bin/env bash
set -euo pipefail

echo "Checking latest Minecraft version..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/scripts/version-resolve.sh"

echo "  Minecraft: ${MINECRAFT_VERSION}"

TAG_BASE="${IMAGE_NAME:-minecraft-server}"
VERSION_ID="${MINECRAFT_VERSION}"

exec docker build \
  --build-arg "MINECRAFT_VERSION=${MINECRAFT_VERSION}" \
  -t "${TAG_BASE}:${VERSION_ID}" \
  -t "${TAG_BASE}:latest" \
  "${@}" \
  .
