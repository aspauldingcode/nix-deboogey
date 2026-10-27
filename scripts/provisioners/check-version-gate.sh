#!/usr/bin/env bash
set -euo pipefail
# Abort if macOS major version doesn't match expected pre_26 flag.
MAJOR=$(sw_vers -productVersion | cut -d. -f1)
echo "macOS ${MAJOR} | codename=${MACOS_CODENAME:-?} | pre_26=${EXPECTED_PRE_26:-true}"
if [ "${EXPECTED_PRE_26:-true}" = "true" ] && [ "$MAJOR" -ge 26 ]; then
  echo "FATAL: expected < 26, got $MAJOR"; exit 1
fi
if [ "${EXPECTED_PRE_26:-true}" = "false" ] && [ "$MAJOR" -lt 26 ]; then
  echo "FATAL: expected >= 26, got $MAJOR"; exit 1
fi
echo "Version gate passed."
