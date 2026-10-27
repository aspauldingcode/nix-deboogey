#!/usr/bin/env bash
set -euo pipefail
# Install Plugin Playground tweak loader (macOS >= 26)
echo "==> Installing Plugin Playground..."
if [ -n "${PLUGIN_PLAYGROUND_PKG_URL:-}" ]; then
  curl -fSL --retry 3 -o /tmp/playground.pkg "$PLUGIN_PLAYGROUND_PKG_URL"
  sudo installer -pkg /tmp/playground.pkg -target /
  rm -f /tmp/playground.pkg
else
  # Build from source if prebuilt package URL is not supplied
  command -v cmake >/dev/null 2>&1 || brew install cmake 2>/dev/null || true
  TMP=$(mktemp -d /tmp/playground-XXXXXX)
  git clone --depth 1 https://github.com/CoreBedtime/playground.git "$TMP/src"
  if [ -f "$TMP/src/install.sh" ]; then
    (cd "$TMP/src" && sh ./install.sh)
  elif [ -f "$TMP/src/build.sh" ]; then
    (cd "$TMP/src" && sh ./build.sh)
  else
    cmake -B "$TMP/src/build" -S "$TMP/src" -DCMAKE_BUILD_TYPE=Release
    cmake --build "$TMP/src/build"
    APP=$(find "$TMP/src" -name "*.app" | head -n 1)
    [ -n "$APP" ] && sudo cp -R "$APP" /Applications/
  fi
  rm -rf "$TMP"
fi
echo "Plugin Playground provisioned."
