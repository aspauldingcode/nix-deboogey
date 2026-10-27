#!/usr/bin/env bash
set -euo pipefail
# Disable System Integrity Protection (SIP) & enable arm64e ABI for tweak injection
echo "==> Configuring SIP & boot-args..."
sudo csrutil disable 2>/dev/null || sudo csrutil enable --without debug --without nvram --without fs --without kext 2>/dev/null || true
sudo nvram boot-args="-arm64e_preview_abi" 2>/dev/null || true
csrutil status || true
