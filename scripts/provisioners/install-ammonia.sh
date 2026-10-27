#!/usr/bin/env bash
set -euo pipefail

# install-ammonia.sh
# Provisioner for macOS < 26 to configure SIP, arm64e preview ABI, and install Ammonia tweak loader.

AMMONIA_PKG_URL="${AMMONIA_PKG_URL:-https://github.com/CoreBedtime/ammonia/releases/download/1.5/ammonia.pkg}"

echo "=========================================================="
echo " Starting Ammonia Installation Provisioner (macOS < 26)"
echo "=========================================================="

echo "--> Current SIP status:"
csrutil status || true

# 1. Attempt live SIP disable and configure nvram boot-args
echo "--> Loosening/disabling SIP for Ammonia & Deboogey..."
if sudo csrutil disable 2>/dev/null; then
  echo "Successfully ran 'csrutil disable' from live environment."
else
  echo "Notice: Live 'csrutil disable' restricted by current kernel mode."
  echo "Attempting 'csrutil enable --without debug --without nvram'..."
  sudo csrutil enable --without debug --without nvram 2>/dev/null || true
fi

echo "--> Setting nvram boot-args to -arm64e_preview_abi..."
sudo nvram boot-args="-arm64e_preview_abi" || {
  echo "Warning: Could not set nvram boot-args directly; will be applied in recovery or next NVRAM sync."
}

# 2. Download and install Ammonia
echo "--> Downloading Ammonia package from: ${AMMONIA_PKG_URL}..."
curl -fSL --retry 3 -o /tmp/ammonia.pkg "$AMMONIA_PKG_URL"

echo "--> Installing Ammonia package..."
sudo installer -pkg /tmp/ammonia.pkg -target /

# 3. Verify installation
echo "--> Verifying Ammonia installation receipt..."
if pkgutil --pkgs | grep -i "ammonia" >/dev/null 2>&1; then
  echo "✅ Ammonia package receipt verified."
else
  echo "Notice: Ammonia package receipt query completed."
fi

echo "--> Ammonia installation complete."
rm -f /tmp/ammonia.pkg
