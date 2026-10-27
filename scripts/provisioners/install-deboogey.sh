#!/usr/bin/env bash
set -euo pipefail
# Install Xcode Command Line Tools & Deboogey into /Applications
echo "==> Ensuring Xcode Command Line Tools..."
if ! xcode-select -p >/dev/null 2>&1; then
  touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  PKG=$(softwareupdate -l 2>/dev/null | awk -F"*" '/Command Line Tools/ {print $2}' | sed 's/^ *//' | head -n 1 || true)
  [ -n "$PKG" ] && sudo softwareupdate -i "$PKG" || xcode-select --install || true
  rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
fi

echo "==> Installing Deboogey..."
WORK_DIR=$(mktemp -d /tmp/deboogey-XXXXXX)
cd "$WORK_DIR"

URL="${DEBOOGEY_DOWNLOAD_URL:-}"
if [ -z "$URL" ]; then
  URL=$(curl -sSL -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/theoderoy/Deboogey/releases/latest \
    | grep -o 'https://github.com/theoderoy/Deboogey/releases/download/[^"]*' | head -n 1 || true)
fi
URL="${URL:-https://github.com/theoderoy/Deboogey/releases/download/rel-7.2/Deboogey.aar}"

ARCHIVE=$(basename "${URL%%\?*}")
curl -fSL --retry 3 -o "$ARCHIVE" "$URL"

sudo rm -rf /Applications/Deboogey.app
case "$ARCHIVE" in
  *.aar)
    mkdir -p out && aa extract -i "$ARCHIVE" -d out
    sudo cp -R "$(find out -name "*.app" | head -n 1)" /Applications/Deboogey.app
    ;;
  *.dmg)
    MNT=$(mktemp -d /tmp/mnt-XXXXXX)
    hdiutil attach "$ARCHIVE" -mountpoint "$MNT" -nobrowse -quiet
    sudo cp -R "$(find "$MNT" -maxdepth 2 -name "*.app" | head -n 1)" /Applications/Deboogey.app
    hdiutil detach "$MNT" -quiet && rm -rf "$MNT"
    ;;
  *.zip)
    unzip -q "$ARCHIVE" -d out
    sudo cp -R "$(find out -name "*.app" | head -n 1)" /Applications/Deboogey.app
    ;;
  *.pkg)
    sudo installer -pkg "$ARCHIVE" -target /
    ;;
esac

sudo xattr -dr com.apple.quarantine /Applications/Deboogey.app 2>/dev/null || true
sudo chown -R admin:staff /Applications/Deboogey.app 2>/dev/null || true

cd / && rm -rf "$WORK_DIR"
[ -d "/Applications/Deboogey.app" ] || { echo "Deboogey installation failed"; exit 1; }
echo "Deboogey installed to /Applications/Deboogey.app."
