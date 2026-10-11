#!/usr/bin/env bash
set -euo pipefail

GODOT_VERSION="4.6-stable"
INSTALL_DIR="/opt/godot/${GODOT_VERSION}"
BIN_NAME="Godot_v${GODOT_VERSION}_linux.x86_64"
ZIP_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
TMP_ZIP="/tmp/godot-${GODOT_VERSION}.zip"

sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends unzip ca-certificates libxcursor1 libxi6 libxinerama1 libxrandr2 libglu1-mesa libasound2t64 >/dev/null

need_install=1
if [ -x "${INSTALL_DIR}/${BIN_NAME}" ] && [ -x /usr/local/bin/godot ]; then
  if /usr/local/bin/godot --version 2>/dev/null | grep -q '^4\.6'; then
    need_install=0
  fi
fi

if [ "${need_install}" -eq 1 ]; then
  sudo mkdir -p "${INSTALL_DIR}"
  curl -fsSL -o "${TMP_ZIP}" "${ZIP_URL}"
  sudo unzip -o "${TMP_ZIP}" -d "${INSTALL_DIR}"
  sudo chmod +x "${INSTALL_DIR}/${BIN_NAME}"
  sudo ln -sfn "${INSTALL_DIR}/${BIN_NAME}" /usr/local/bin/godot
  rm -f "${TMP_ZIP}"
fi

echo "godot: $(godot --version)"
cd /workspace
godot --headless --path . --import
echo "godot import complete"
