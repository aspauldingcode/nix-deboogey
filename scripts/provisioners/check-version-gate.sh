#!/usr/bin/env bash
set -euo pipefail

# check-version-gate.sh
# Verifies that the running macOS VM matches the expected version family (< 26 vs >= 26).
# Aborts immediately if the assumption does not match sw_vers output to prevent silent drift.

EXPECTED_PRE_26="${EXPECTED_PRE_26:-true}"
MACOS_CODENAME="${MACOS_CODENAME:-unknown}"

PRODUCT_VERSION=$(sw_vers -productVersion)
MAJOR_VERSION=$(echo "$PRODUCT_VERSION" | cut -d. -f1)

echo "=========================================================="
echo " macOS Version Gate Verification"
echo " Codename:        ${MACOS_CODENAME}"
echo " Product Version: ${PRODUCT_VERSION} (Major: ${MAJOR_VERSION})"
echo " Expected < 26:   ${EXPECTED_PRE_26}"
echo "=========================================================="

if [ "$EXPECTED_PRE_26" = "true" ]; then
  if [ "$MAJOR_VERSION" -ge 26 ]; then
    echo "❌ FATAL: Expected macOS < 26 for ${MACOS_CODENAME}, but detected macOS ${MAJOR_VERSION} (${PRODUCT_VERSION})!"
    echo "Ammonia tweak loader cannot run on macOS >= 26. Aborting Packer build."
    exit 1
  fi
  echo "✅ Version gate passed: macOS ${MAJOR_VERSION} < 26. Using Ammonia tweak loader."
else
  if [ "$MAJOR_VERSION" -lt 26 ]; then
    echo "❌ FATAL: Expected macOS >= 26 for ${MACOS_CODENAME}, but detected macOS ${MAJOR_VERSION} (${PRODUCT_VERSION})!"
    echo "Plugin Playground requires macOS >= 26. Aborting Packer build."
    exit 1
  fi
  echo "✅ Version gate passed: macOS ${MAJOR_VERSION} >= 26. Using Plugin Playground tweak loader."
fi
