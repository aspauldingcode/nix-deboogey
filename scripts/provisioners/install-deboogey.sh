#!/usr/bin/env bash
set -euo pipefail

# install-deboogey.sh
# Shared provisioner to install Deboogey and Xcode Command Line Tools on macOS Tart VMs.

echo "=========================================================="
echo " Starting Deboogey Installation Provisioner"
echo "=========================================================="

# 1. Ensure Xcode Command Line Tools are installed
echo "--> Checking Xcode Command Line Tools..."
if xcode-select -p >/dev/null 2>&1; then
  echo "Xcode Command Line Tools already present at: $(xcode-select -p)"
else
  echo "Xcode Command Line Tools not detected. Installing headlessly..."
  touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  
  # Trigger software update check for Command Line Tools package
  CLT_PACKAGE=$(softwareupdate -l 2>/dev/null | grep -B 1 -E "Command Line Tools" | awk -F"*" '/\*/ {print $2}' | sed -e 's/^ *//' | head -n 1 || true)
  if [ -n "$CLT_PACKAGE" ]; then
    echo "Found package: ${CLT_PACKAGE}. Installing..."
    sudo softwareupdate -i "$CLT_PACKAGE" --verbose || true
  else
    echo "Falling back to xcode-select --install trigger..."
    xcode-select --install || true
    echo "Waiting for Xcode CLI tools installation to settle..."
    for i in {1..30}; do
      if xcode-select -p >/dev/null 2>&1; then
        break
      fi
      sleep 5
    done
  fi
  rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
fi

# Ensure Rosetta 2 if applicable (Apple Silicon)
if [ "$(uname -m)" = "arm64" ]; then
  echo "--> Ensuring Rosetta 2 is available..."
  softwareupdate --install-rosetta --agree-to-license || true
fi

# 2. Resolve and download Deboogey release
echo "--> Locating Deboogey release..."
WORK_DIR=$(mktemp -d /tmp/deboogey-install-XXXXXX)
cd "$WORK_DIR"

DOWNLOAD_URL="${DEBOOGEY_DOWNLOAD_URL:-}"

if [ -z "$DOWNLOAD_URL" ]; then
  echo "Querying GitHub API for latest Deboogey release..."
  API_RESPONSE=$(curl -sSL -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/theoderoy/Deboogey/releases/latest || true)
  DOWNLOAD_URL=$(echo "$API_RESPONSE" | grep -o 'https://github.com/theoderoy/Deboogey/releases/download/[^"]*' | head -n 1 || true)

  # Fallback if GitHub API is rate-limited or fails
  if [ -z "$DOWNLOAD_URL" ]; then
    echo "GitHub API unavailable or rate-limited; checking redirect location..."
    LATEST_TAG=$(curl -sI https://github.com/theoderoy/Deboogey/releases/latest | grep -i "^location:" | sed -e 's/.*tag\///' | tr -d '\r\n')
    if [ -n "$LATEST_TAG" ]; then
      DOWNLOAD_URL="https://github.com/theoderoy/Deboogey/releases/download/${LATEST_TAG}/Deboogey.zip"
      echo "Inferred asset download URL: ${DOWNLOAD_URL}"
    fi
  fi
fi

# Ultimate fallback if no asset URL could be dynamically determined
if [ -z "$DOWNLOAD_URL" ]; then
  DOWNLOAD_URL="https://github.com/theoderoy/Deboogey/releases/download/rel-7.2/Deboogey.aar"
  echo "Using default fallback URL: ${DOWNLOAD_URL}"
fi

echo "--> Downloading Deboogey from: ${DOWNLOAD_URL}"
ARCHIVE_NAME=$(basename "${DOWNLOAD_URL%%\?*}")
if ! curl -fSL --retry 3 -o "$ARCHIVE_NAME" "$DOWNLOAD_URL"; then
  echo "Primary download failed. Attempting release archive fallback..."
  ARCHIVE_NAME="Deboogey.aar"
  curl -fSL --retry 3 -o "$ARCHIVE_NAME" "https://github.com/theoderoy/Deboogey/releases/download/rel-7.2/Deboogey.aar" || {
    echo "❌ FATAL: Could not download Deboogey archive from GitHub releases."
    exit 1
  }
fi

# 3. Extract / Mount and install Deboogey.app
echo "--> Extracting/installing ${ARCHIVE_NAME}..."
sudo rm -rf /Applications/Deboogey.app

if [[ "$ARCHIVE_NAME" =~ \.aar$ ]]; then
  echo "Extracting Apple Archive (.aar)..."
  mkdir -p unarchived
  aa extract -v -i "$ARCHIVE_NAME" -d unarchived
  if [ -d "unarchived/Deboogey.app" ]; then
    sudo cp -R "unarchived/Deboogey.app" /Applications/
  else
    APP_FIND=$(find unarchived -name "*.app" | head -n 1)
    if [ -n "$APP_FIND" ]; then
      sudo cp -R "$APP_FIND" /Applications/Deboogey.app
    fi
  fi
  rm -rf unarchived
elif [[ "$ARCHIVE_NAME" =~ \.dmg$ ]]; then
  MOUNT_DIR=$(mktemp -d /tmp/deboogey-mount-XXXXXX)
  hdiutil attach "$ARCHIVE_NAME" -mountpoint "$MOUNT_DIR" -nobrowse -quiet
  if [ -d "$MOUNT_DIR/Deboogey.app" ]; then
    sudo cp -R "$MOUNT_DIR/Deboogey.app" /Applications/
  else
    APP_FIND=$(find "$MOUNT_DIR" -maxdepth 2 -name "*.app" | head -n 1)
    if [ -n "$APP_FIND" ]; then
      sudo cp -R "$APP_FIND" /Applications/Deboogey.app
    fi
  fi
  hdiutil detach "$MOUNT_DIR" -quiet || true
  rm -rf "$MOUNT_DIR"
elif [[ "$ARCHIVE_NAME" =~ \.zip$ ]]; then
  unzip -q "$ARCHIVE_NAME" -d unzipped
  if [ -d "unzipped/Deboogey.app" ]; then
    sudo cp -R "unzipped/Deboogey.app" /Applications/
  else
    APP_FIND=$(find unzipped -name "*.app" | head -n 1)
    if [ -n "$APP_FIND" ]; then
      sudo cp -R "$APP_FIND" /Applications/Deboogey.app
    fi
  fi
elif [[ "$ARCHIVE_NAME" =~ \.pkg$ ]]; then
  sudo installer -pkg "$ARCHIVE_NAME" -target /
else
  echo "Unrecognized file format: ${ARCHIVE_NAME}"
  exit 1
fi

# Remove quarantine attribute and set permissions
if [ -d "/Applications/Deboogey.app" ]; then
  sudo xattr -dr com.apple.quarantine /Applications/Deboogey.app || true
  sudo chown -R admin:staff /Applications/Deboogey.app || true
fi

# 4. Verify installation
echo "--> Verifying /Applications/Deboogey.app..."
if [ -d "/Applications/Deboogey.app" ]; then
  echo "✅ Deboogey successfully installed at /Applications/Deboogey.app"
else
  echo "❌ FATAL: /Applications/Deboogey.app not found after installation step!"
  exit 1
fi

# Cleanup
cd /
rm -rf "$WORK_DIR"
