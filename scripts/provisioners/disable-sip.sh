#!/usr/bin/env bash
set -euo pipefail

# disable-sip.sh
# Disables System Integrity Protection (SIP) fully and sets arm64e boot-args across all VMs.

echo "=========================================================="
echo " Fully Disabling System Integrity Protection (SIP)"
echo "=========================================================="

echo "--> Current SIP status:"
csrutil status || true

echo "--> Executing full SIP disablement..."
if sudo csrutil disable 2>/dev/null; then
  echo "✅ 'csrutil disable' succeeded."
else
  echo "Notice: Live 'csrutil disable' returned non-zero. Attempting maximum SIP loosening..."
  sudo csrutil enable --without debug --without nvram --without fs --without kext 2>/dev/null || true
fi

echo "--> Setting nvram boot-args to -arm64e_preview_abi..."
sudo nvram boot-args="-arm64e_preview_abi" 2>/dev/null || {
  echo "Notice: nvram boot-args could not be set directly in live user mode."
}

echo "--> Resulting SIP status:"
csrutil status || true
