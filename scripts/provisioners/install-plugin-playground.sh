#!/usr/bin/env bash
set -euo pipefail

# install-plugin-playground.sh
# Provisioner for macOS >= 26 to loosen SIP for debugging and install Plugin Playground.

echo "=========================================================="
echo " Starting Plugin Playground Installation (macOS >= 26)"
echo "=========================================================="

# 1. Full SIP disablement and boot-args
echo "--> Applying full SIP disable (csrutil disable)..."
if sudo csrutil disable 2>/dev/null; then
  echo "✅ SIP disabled fully."
else
  echo "Notice: Live 'csrutil disable' restricted. Attempting maximum loosening..."
  sudo csrutil enable --without debug --without nvram --without fs --without kext 2>/dev/null || true
fi

echo "--> Setting nvram boot-args to -arm64e_preview_abi..."
sudo nvram boot-args="-arm64e_preview_abi" 2>/dev/null || true

# 2. Check if a pre-built PKG URL was supplied via environment
PLUGIN_PLAYGROUND_PKG_URL="${PLUGIN_PLAYGROUND_PKG_URL:-}"

if [ -n "$PLUGIN_PLAYGROUND_PKG_URL" ]; then
  echo "--> Using pre-built Plugin Playground package from: ${PLUGIN_PLAYGROUND_PKG_URL}"
  curl -fSL --retry 3 -o /tmp/PluginPlayground.pkg "$PLUGIN_PLAYGROUND_PKG_URL"
  sudo installer -pkg /tmp/PluginPlayground.pkg -target /
  rm -f /tmp/PluginPlayground.pkg
else
  echo "--> Pre-built package URL not provided. Compiling Plugin Playground from source..."
  
  # Ensure CMake is available
  if ! command -v cmake >/dev/null 2>&1; then
    echo "CMake not found. Installing portable CMake..."
    CMAKE_VERSION="3.30.5"
    CMAKE_TAR="cmake-${CMAKE_VERSION}-macos-universal.tar.gz"
    CMAKE_URL="https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/${CMAKE_TAR}"
    curl -fSL --retry 3 -o "/tmp/${CMAKE_TAR}" "$CMAKE_URL"
    sudo tar -xzf "/tmp/${CMAKE_TAR}" -C /usr/local/ --strip-components=1
    rm -f "/tmp/${CMAKE_TAR}"
  fi
  echo "CMake version: $(cmake --version | head -n 1)"

  BUILD_DIR=$(mktemp -d /tmp/plugin-playground-build-XXXXXX)
  cd "$BUILD_DIR"

  echo "--> Cloning CoreBedtime/playground repository..."
  git clone --depth 1 https://github.com/CoreBedtime/playground.git src
  cd src

  echo "--> Running install script..."
  if [ -f "./install.sh" ]; then
    sh ./install.sh
  elif [ -f "./build.sh" ]; then
    sh ./build.sh
  else
    mkdir -p build && cd build
    cmake .. -DCMAKE_BUILD_TYPE=Release
    cmake --build .
  fi

  # Locate and install resulting .pkg or .app
  PKG_PATH=$(find . -name "PluginPlayground*.pkg" | head -n 1 || true)
  if [ -n "$PKG_PATH" ]; then
    echo "Found built package: ${PKG_PATH}. Installing..."
    sudo installer -pkg "$PKG_PATH" -target /
  else
    APP_PATH=$(find . -name "Plugin Playground.app" | head -n 1 || true)
    if [ -n "$APP_PATH" ]; then
      echo "Found built app: ${APP_PATH}. Copying to /Applications/..."
      sudo cp -R "$APP_PATH" "/Applications/Plugin Playground.app"
    fi
  fi

  cd /
  rm -rf "$BUILD_DIR"
fi

# 3. Verify Plugin Playground presence
echo "--> Verifying Plugin Playground installation..."
if [ -d "/Applications/Plugin Playground.app" ] || pkgutil --pkgs | grep -i "pluginplayground" >/dev/null 2>&1; then
  echo "✅ Plugin Playground installed successfully."
else
  echo "Warning: Neither /Applications/Plugin Playground.app nor package receipt was found."
fi
