#!/usr/bin/env bash
# create-prebuilt.sh - Create and push a Deboogey prebuilt Tart VM
# Usage: ./scripts/create-prebuilt.sh <version> [--push]
# Versions: golden-gate, tahoe, sequoia, sonoma, ventura, monterey
set -euo pipefail

VERSION="${1:-}"
DO_PUSH="${2:-}"

if [ -z "$VERSION" ]; then
  echo "Usage: $0 <version> [--push]"
  echo "Versions: golden-gate, tahoe, sequoia, sonoma, ventura, monterey"
  exit 1
fi

case "$VERSION" in
  golden-gate)
    BASE_IMAGE="ghcr.io/cirruslabs/macos-golden-gate-vanilla:latest"
    TARGET_IMAGE="ghcr.io/aspauldingcode/nix-deboogey/macos-golden-gate-deboogey:latest"
    PRE_26="false"
    ;;
  tahoe)
    BASE_IMAGE="ghcr.io/cirruslabs/macos-tahoe-vanilla:latest"
    TARGET_IMAGE="ghcr.io/aspauldingcode/nix-deboogey/macos-tahoe-deboogey:latest"
    PRE_26="false"
    ;;
  sequoia)
    BASE_IMAGE="ghcr.io/cirruslabs/macos-sequoia-vanilla:latest"
    TARGET_IMAGE="ghcr.io/aspauldingcode/nix-deboogey/macos-sequoia-deboogey:latest"
    PRE_26="true"
    ;;
  sonoma)
    BASE_IMAGE="ghcr.io/cirruslabs/macos-sonoma-vanilla:latest"
    TARGET_IMAGE="ghcr.io/aspauldingcode/nix-deboogey/macos-sonoma-deboogey:latest"
    PRE_26="true"
    ;;
  ventura)
    BASE_IMAGE="ghcr.io/cirruslabs/macos-ventura-vanilla:latest"
    TARGET_IMAGE="ghcr.io/aspauldingcode/nix-deboogey/macos-ventura-deboogey:latest"
    PRE_26="true"
    ;;
  monterey)
    BASE_IMAGE="ghcr.io/cirruslabs/macos-monterey-vanilla:latest"
    TARGET_IMAGE="ghcr.io/aspauldingcode/nix-deboogey/macos-monterey-deboogey:latest"
    PRE_26="true"
    ;;
  *)
    echo "❌ Error: Unknown version '$VERSION'"
    echo "Supported: golden-gate, tahoe, sequoia, sonoma, ventura, monterey"
    exit 1
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKR_TEMPLATE="$SCRIPT_DIR/../packer/templates/macos-${VERSION}-deboogey.pkr.hcl"

echo "=========================================================="
echo " Building Prebuilt Deboogey Tart VM: $VERSION"
echo " Base vanilla image: $BASE_IMAGE"
echo " Target OCI image:   $TARGET_IMAGE"
echo " Pre-26 flag:        $PRE_26"
echo "=========================================================="

if command -v packer >/dev/null 2>&1; then
  echo "--> Running Packer build using template: $PKR_TEMPLATE"
  packer init "$PKR_TEMPLATE"
  packer build -var "pre_26=$PRE_26" "$PKR_TEMPLATE"
else
  echo "Packer not installed locally. Building via direct Tart orchestration..."
  VM_NAME="macos-${VERSION}-deboogey"
  
  tart stop "$VM_NAME" 2>/dev/null || true
  tart delete "$VM_NAME" 2>/dev/null || true

  echo "--> Pulling base vanilla image: $BASE_IMAGE"
  tart pull "$BASE_IMAGE"

  echo "--> Cloning to $VM_NAME..."
  tart clone "$BASE_IMAGE" "$VM_NAME"

  echo "--> Running provisioners inside $VM_NAME..."
  tart run "$VM_NAME" --no-graphics &
  VM_PID=$!
  trap 'kill $VM_PID 2>/dev/null || true; tart stop "$VM_NAME" 2>/dev/null || true' EXIT

  sleep 20
  tart exec "$VM_NAME" EXPECTED_PRE_26="$PRE_26" MACOS_CODENAME="$VERSION" bash -s < "$SCRIPT_DIR/provisioners/check-version-gate.sh"
  tart exec "$VM_NAME" bash -s < "$SCRIPT_DIR/provisioners/disable-sip.sh"
  tart exec "$VM_NAME" bash -s < "$SCRIPT_DIR/provisioners/install-deboogey.sh"

  if [ "$PRE_26" = "true" ]; then
    tart exec "$VM_NAME" bash -s < "$SCRIPT_DIR/provisioners/install-ammonia.sh"
  else
    tart exec "$VM_NAME" bash -s < "$SCRIPT_DIR/provisioners/install-plugin-playground.sh"
  fi

  tart stop "$VM_NAME"
fi

if [ "$DO_PUSH" = "--push" ]; then
  echo "--> Pushing to GHCR: $TARGET_IMAGE"
  tart push "macos-${VERSION}-deboogey" "$TARGET_IMAGE"
  tart push "macos-${VERSION}-deboogey" "ghcr.io/aspauldingcode/nix-deboogey/macos-${VERSION}-deboogey:$(date +%Y%m%d)"
fi

echo "✅ Prebuilt for $VERSION completed successfully."
