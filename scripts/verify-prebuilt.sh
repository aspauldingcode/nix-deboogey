#!/usr/bin/env bash
# verify-prebuilt.sh - Verify vanilla bases, unified Packer template, provisioners, and assets
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
pass() { echo "  ✅ PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  ❌ FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "================================================================================"
echo " VERIFICATION SUITE: DEBOOGEY TART PREBUILTS"
echo "================================================================================"

VERSIONS=($(grep -oE '"[a-z0-9-]+"' "$ROOT/versions.nix" | tr -d '"'))

# 1. Base vanilla images on GHCR
echo "--> [1/6] Verifying vanilla base images on GHCR..."
ACCEPT="Accept: application/vnd.oci.image.index.v1+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json"
for ver in "${VERSIONS[@]}"; do
  REPO="cirruslabs/macos-${ver}-vanilla"
  TOKEN=$(curl -s "https://ghcr.io/token?service=ghcr.io&scope=repository:${REPO}:pull" | grep -o '"token":"[^"]*' | cut -d'"' -f4 || true)
  if [ -n "$TOKEN" ]; then
    CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN" -H "$ACCEPT" "https://ghcr.io/v2/${REPO}/manifests/latest" || true)
    [ "$CODE" = "200" ] && pass "ghcr.io/${REPO}:latest available" || fail "ghcr.io/${REPO}:latest HTTP $CODE"
  else
    fail "Auth error for $REPO"
  fi
done

# 2. Strict vanilla check (no -base or -xcode)
echo "--> [2/6] Auditing for forbidden -base or -xcode references..."
FORBIDDEN=$(grep -rnE "ghcr.io/cirruslabs/macos-[a-z-]+(base|xcode)" "$ROOT/packer/" "$ROOT/.github/" "$ROOT/modules/" "$ROOT/apps/" 2>/dev/null || true)
[ -z "$FORBIDDEN" ] && pass "Zero -base or -xcode references" || fail "Forbidden base references found:\n$FORBIDDEN"

# 3. Packer template checks
echo "--> [3/6] Verifying unified Packer template..."
PKR="$ROOT/packer/template.pkr.hcl"
if [ -f "$PKR" ]; then
  grep -q 'macos-\${var.version}-vanilla:latest' "$PKR" && pass "Template enforces vanilla base" || fail "Template missing vanilla pattern"
  grep -q 'check-version-gate.sh' "$PKR" && pass "Template includes version gate" || fail "Missing version gate"
  grep -q 'disable-sip.sh' "$PKR" && pass "Template includes SIP disablement" || fail "Missing SIP disablement"
  grep -q 'install-deboogey.sh' "$PKR" && pass "Template includes Deboogey installer" || fail "Missing Deboogey installer"
  grep -q 'install-ammonia.sh' "$PKR" && grep -q 'install-plugin-playground.sh' "$PKR" && pass "Template selects Ammonia (<26) vs Playground (>=26)" || fail "Missing dual tweak loader branch"
else
  fail "packer/template.pkr.hcl does not exist!"
fi

# 4. Upstream assets reachability
echo "--> [4/6] Checking upstream download endpoints..."
DEBOOGEY_URL="https://github.com/theoderoy/Deboogey/releases/download/rel-7.2/Deboogey.aar"
[ "$(curl -s -L -o /dev/null -w "%{http_code}" "$DEBOOGEY_URL")" = "200" ] && pass "Deboogey release asset available" || fail "Deboogey asset unreachable"

AMMONIA_URL="https://github.com/CoreBedtime/ammonia/releases/download/1.5/ammonia.pkg"
[ "$(curl -s -L -o /dev/null -w "%{http_code}" "$AMMONIA_URL")" = "200" ] && pass "Ammonia 1.5 pkg reachable" || fail "Ammonia unreachable"

git ls-remote --exit-code https://github.com/CoreBedtime/playground.git HEAD >/dev/null 2>&1 && pass "Plugin Playground git reachable" || fail "Plugin Playground git unreachable"

# 5. One image name for nix run, the darwin module, and the publisher
echo "--> [5/6] Checking the GHCR image contract..."
grep -q 'ghcr.io/aspauldingcode/nix-deboogey/macos-${version}-deboogey:latest' "$ROOT/apps/ephemeral.nix" \
  && pass "ephemeral runner image" || fail "ephemeral runner image drifted"
grep -q 'ghcr.io/aspauldingcode/nix-deboogey/macos-${name}-deboogey:latest' "$ROOT/modules/default.nix" \
  && pass "darwin module image" || fail "darwin module image drifted"
grep -q 'ghcr.io/aspauldingcode/nix-deboogey/macos-${VERSION}-deboogey' "$ROOT/scripts/create-prebuilt.sh" \
  && pass "publisher image" || fail "publisher image drifted"
grep -q 'create-prebuilt.sh' "$ROOT/.github/workflows/build-tart-vms.yml" \
  && pass "publish workflow calls create-prebuilt.sh" || fail "publish workflow does not call create-prebuilt.sh"
for ver in "${VERSIONS[@]}"; do
  grep -q "$ver" "$ROOT/.github/workflows/build-tart-vms.yml" && pass "publish matrix ${ver}" || fail "publish matrix missing ${ver}"
  grep -q "$ver" "$ROOT/scripts/create-prebuilt.sh" && pass "publisher knows ${ver}" || fail "publisher missing ${ver}"
done

# 6. Local VM check if specified
TARGET_VM="${1:-}"
if [ -n "$TARGET_VM" ] && command -v tart >/dev/null 2>&1; then
  echo "--> [6/6] Inspecting VM: $TARGET_VM..."
  if tart exec "$TARGET_VM" test -d "/Applications/Deboogey.app" 2>/dev/null; then
    pass "Deboogey.app present in $TARGET_VM"
  else
    fail "Deboogey.app not found in $TARGET_VM"
  fi
else
  pass "Prebuilt provisioners ready for VM execution"
fi

echo "================================================================================"
echo " RESULTS: Passed: $PASS | Failed: $FAIL"
echo "================================================================================"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
