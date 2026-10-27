#!/usr/bin/env bash
set -euo pipefail
# create-prebuilt.sh <version> [--push]
# Supported: golden-gate, tahoe, sequoia, sonoma, ventura, monterey
VERSION="${1:-}"
DO_PUSH="${2:-}"

[ -z "$VERSION" ] && { echo "Usage: $0 <version> [--push]"; exit 1; }

case "$VERSION" in
  golden-gate|tahoe) PRE_26="false" ;;
  sequoia|sonoma|ventura|monterey) PRE_26="true" ;;
  *) echo "Unknown version: $VERSION"; exit 1 ;;
esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="ghcr.io/aspauldingcode/nix-deboogey/macos-${VERSION}-deboogey"

echo "==> Building Deboogey Tart VM: $VERSION (pre_26=$PRE_26)..."
packer init "$ROOT/packer/template.pkr.hcl"
packer build -var "version=$VERSION" -var "pre_26=$PRE_26" "$ROOT/packer/template.pkr.hcl"

if [ "$DO_PUSH" = "--push" ]; then
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    export TART_REGISTRY_HOSTNAME=ghcr.io
    export TART_REGISTRY_USERNAME="${GITHUB_ACTOR:-aspauldingcode}"
    export TART_REGISTRY_PASSWORD="$GITHUB_TOKEN"
  fi
  echo "==> Pushing ${TARGET}..."
  tart push "macos-${VERSION}-deboogey" "${TARGET}:latest"
  tart push "macos-${VERSION}-deboogey" "${TARGET}:$(date +%Y%m%d)"
  if [ -n "${GITHUB_TOKEN:-}" ] && command -v gh >/dev/null 2>&1; then
    PKG=$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "nix-deboogey/macos-${VERSION}-deboogey")
    echo "==> Marking GitHub Package public: nix-deboogey/macos-${VERSION}-deboogey"
    GH_TOKEN="$GITHUB_TOKEN" gh api --method PUT \
      -H "Accept: application/vnd.github+json" \
      "/user/packages/container/${PKG}/visibility" \
      -f visibility=public \
      || echo "Warning: image was pushed, but the package visibility API did not accept this token."
  fi
fi
echo "Done: ${TARGET}"
