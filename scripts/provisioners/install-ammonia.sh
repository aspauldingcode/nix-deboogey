#!/usr/bin/env bash
set -euo pipefail
# Install Ammonia tweak loader (macOS < 26)
PKG_URL="${AMMONIA_PKG_URL:-https://github.com/CoreBedtime/ammonia/releases/download/1.5/ammonia.pkg}"
echo "==> Installing Ammonia from $PKG_URL..."
curl -fSL --retry 3 -o /tmp/ammonia.pkg "$PKG_URL"
sudo installer -pkg /tmp/ammonia.pkg -target /
rm -f /tmp/ammonia.pkg
echo "Ammonia installed successfully."
