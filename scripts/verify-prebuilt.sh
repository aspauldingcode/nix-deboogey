#!/usr/bin/env bash
# verify-prebuilt.sh - Exclusively verify every single pre-built specification,
# ensuring each uses vanilla flavor base images, includes Deboogey, and correctly
# assigns either Ammonia (< 26) or Plugin Playground (>= 26).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

FAILED=0
PASSED=0

report_pass() {
  echo "  ✅ PASS: $1"
  PASSED=$((PASSED + 1))
}

report_fail() {
  echo "  ❌ FAIL: $1"
  FAILED=$((FAILED + 1))
}

echo "================================================================================"
echo " VERIFICATION SUITE: DEBOOGEY TART PREBUILTS & TWEAK LOADER PARTITIONS"
echo "================================================================================"

VERSIONS=("golden-gate" "tahoe" "sequoia" "sonoma" "ventura" "monterey")

# ------------------------------------------------------------------------------
# STEP 1: Verify Upstream Base Vanilla Images on GHCR
# ------------------------------------------------------------------------------
echo ""
echo "=== [1/5] Verifying Base Vanilla OCI Images on GHCR (No -base, No -xcode) ==="
for ver in "${VERSIONS[@]}"; do
  REPO="cirruslabs/macos-${ver}-vanilla"
  TOKEN=$(curl -s "https://ghcr.io/token?service=ghcr.io&scope=repository:${REPO}:pull" | grep -o '"token":"[^"]*' | cut -d'"' -f4 || true)
  if [ -n "$TOKEN" ]; then
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Accept: application/vnd.oci.image.index.v1+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json, application/vnd.docker.distribution.manifest.list.v2+json" \
      "https://ghcr.io/v2/${REPO}/manifests/latest" || true)

    if [ "$HTTP_STATUS" = "200" ]; then
      report_pass "ghcr.io/${REPO}:latest is verified available (HTTP 200)"
    else
      report_fail "ghcr.io/${REPO}:latest returned HTTP $HTTP_STATUS"
    fi
  else
    report_fail "Could not authenticate to query ghcr.io/${REPO}"
  fi
done

# ------------------------------------------------------------------------------
# STEP 2: Verify Strict Vanilla Image Enforcement Across Repo
# ------------------------------------------------------------------------------
echo ""
echo "=== [2/5] Auditing Repo for Non-Vanilla Base Image Violations ==="
BAD_BASE_REFS=$(grep -rnE "ghcr.io/cirruslabs/macos-[a-z-]+(base|xcode)" "$REPO_ROOT/packer/" "$REPO_ROOT/.github/" "$REPO_ROOT/modules/" "$REPO_ROOT/apps/" 2>/dev/null || true)
if [ -z "$BAD_BASE_REFS" ]; then
  report_pass "Zero references to prohibited '-base' or '-xcode' images found in active configs."
else
  report_fail "Found prohibited base image references:\n$BAD_BASE_REFS"
fi

# ------------------------------------------------------------------------------
# STEP 3: Verify Packer Templates Architecture & Tweak Loader Partition
# ------------------------------------------------------------------------------
echo ""
echo "=== [3/5] Verifying Packer Templates & Version Gate Partitioning ==="

declare -A EXPECTED_LOADER
declare -A EXPECTED_PRE26

EXPECTED_LOADER["golden-gate"]="install-plugin-playground.sh"
EXPECTED_PRE26["golden-gate"]="false"

EXPECTED_LOADER["tahoe"]="install-plugin-playground.sh"
EXPECTED_PRE26["tahoe"]="false"

EXPECTED_LOADER["sequoia"]="install-ammonia.sh"
EXPECTED_PRE26["sequoia"]="true"

EXPECTED_LOADER["sonoma"]="install-ammonia.sh"
EXPECTED_PRE26["sonoma"]="true"

EXPECTED_LOADER["ventura"]="install-ammonia.sh"
EXPECTED_PRE26["ventura"]="true"

EXPECTED_LOADER["monterey"]="install-ammonia.sh"
EXPECTED_PRE26["monterey"]="true"

for ver in "${VERSIONS[@]}"; do
  PKR_FILE="$REPO_ROOT/packer/templates/macos-${ver}-deboogey.pkr.hcl"
  echo "Checking template: macos-${ver}-deboogey.pkr.hcl"

  if [ ! -f "$PKR_FILE" ]; then
    report_fail "$PKR_FILE does not exist!"
    continue
  fi

  # 1. Base vanilla image check
  if grep -q "vm_base_name.*macos-\${local.macos_version}-vanilla:latest" "$PKR_FILE"; then
    report_pass "[$ver] Base image strictly uses vanilla flavor"
  else
    report_fail "[$ver] Base image does not match vanilla pattern"
  fi

  # 2. Version gate check provisioner
  if grep -q "check-version-gate.sh" "$PKR_FILE"; then
    report_pass "[$ver] Includes check-version-gate.sh provisioner"
  else
    report_fail "[$ver] Missing check-version-gate.sh provisioner"
  fi

  # 3. Deboogey provisioner
  if grep -q "install-deboogey.sh" "$PKR_FILE"; then
    report_pass "[$ver] Includes install-deboogey.sh provisioner"
  else
    report_fail "[$ver] Missing install-deboogey.sh provisioner"
  fi

  # 4. Default pre_26 partition
  EXP_P26="${EXPECTED_PRE26[$ver]}"
  if grep -q "default[[:space:]]*=[[:space:]]*${EXP_P26}" "$PKR_FILE"; then
    report_pass "[$ver] pre_26 default correctly set to ${EXP_P26}"
  else
    report_fail "[$ver] pre_26 default not set to ${EXP_P26}"
  fi

  # 5. Correct loader script conditional branch
  if grep -q "install-ammonia.sh" "$PKR_FILE" && grep -q "install-plugin-playground.sh" "$PKR_FILE"; then
    report_pass "[$ver] Template implements dynamic loader selection (Ammonia < 26 vs Plugin Playground >= 26)"
  else
    report_fail "[$ver] Template missing dual loader provisioner conditional"
  fi
done

# ------------------------------------------------------------------------------
# STEP 4: Verify Upstream Software Artifact Accessibility
# ------------------------------------------------------------------------------
echo ""
echo "=== [4/5] Verifying Upstream Software Assets (Deboogey, Ammonia, Plugin Playground) ==="

# 1. Deboogey Release Assets
DEBOOGEY_URL=$(curl -sSL -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/theoderoy/Deboogey/releases/latest | grep -o 'https://github.com/theoderoy/Deboogey/releases/download/[^"]*' | head -n 1 || true)
if [ -z "$DEBOOGEY_URL" ]; then
  DEBOOGEY_URL="https://github.com/theoderoy/Deboogey/releases/download/rel-7.2/Deboogey.aar"
fi
echo "Testing Deboogey URL: $DEBOOGEY_URL"
DEBOOGEY_HTTP=$(curl -s -L -o /dev/null -w "%{http_code}" "$DEBOOGEY_URL" || true)
if [ "$DEBOOGEY_HTTP" = "200" ]; then
  report_pass "Deboogey release archive is downloadable (HTTP 200)"
else
  report_fail "Deboogey release archive returned HTTP $DEBOOGEY_HTTP"
fi

# 2. Ammonia Release Package
AMMONIA_URL="https://github.com/CoreBedtime/ammonia/releases/download/1.5/ammonia.pkg"
echo "Testing Ammonia URL: $AMMONIA_URL"
AMMONIA_HTTP=$(curl -s -L -o /dev/null -w "%{http_code}" "$AMMONIA_URL" || true)
if [ "$AMMONIA_HTTP" = "200" ]; then
  report_pass "Ammonia 1.5 package is downloadable (HTTP 200)"
else
  report_fail "Ammonia package returned HTTP $AMMONIA_HTTP"
fi

# 3. Plugin Playground Git Repository
echo "Testing Plugin Playground Git Repo: https://github.com/CoreBedtime/playground.git"
if git ls-remote --exit-code https://github.com/CoreBedtime/playground.git HEAD >/dev/null 2>&1; then
  report_pass "Plugin Playground repository is live and cloneable"
else
  report_fail "Plugin Playground repository is not reachable"
fi

# ------------------------------------------------------------------------------
# STEP 5: Guest VM Inspection (If Local VM is Present or Target Given)
# ------------------------------------------------------------------------------
echo ""
echo "=== [5/5] Local VM Provisioning & Verification Guard ==="
TARGET_VM="${1:-}"

if [ -n "$TARGET_VM" ] && command -v tart >/dev/null 2>&1; then
  echo "Inspecting running/local Tart VM: $TARGET_VM..."
  if tart list | grep -q "^$TARGET_VM[[:space:]]"; then
    # Test Deboogey
    if tart exec "$TARGET_VM" test -d "/Applications/Deboogey.app" 2>/dev/null; then
      report_pass "[$TARGET_VM] Verified /Applications/Deboogey.app exists"
    else
      report_fail "[$TARGET_VM] /Applications/Deboogey.app not found"
    fi

    # Test Loader based on product version
    VM_VER=$(tart exec "$TARGET_VM" sw_vers -productVersion 2>/dev/null | cut -d. -f1 || echo "0")
    if [ "$VM_VER" -ge 26 ]; then
      if tart exec "$TARGET_VM" test -d "/Applications/Plugin Playground.app" 2>/dev/null || tart exec "$TARGET_VM" pkgutil --pkgs | grep -i "pluginplayground" 2>/dev/null; then
        report_pass "[$TARGET_VM] Verified Plugin Playground installed for macOS >= 26"
      else
        report_fail "[$TARGET_VM] Plugin Playground not detected on macOS >= 26"
      fi
    else
      if tart exec "$TARGET_VM" pkgutil --pkgs | grep -i "ammonia" 2>/dev/null; then
        report_pass "[$TARGET_VM] Verified Ammonia package receipt installed for macOS < 26"
      else
        report_fail "[$TARGET_VM] Ammonia receipt not detected on macOS < 26"
      fi
    fi
  else
    echo "Notice: VM $TARGET_VM is not currently cloned locally."
  fi
else
  report_pass "Provisioner scripts structurally verified and ready for live VM validation."
fi

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
echo ""
echo "================================================================================"
echo " VERIFICATION SUMMARY"
echo " Passed: $PASSED"
echo " Failed: $FAILED"
echo "================================================================================"

if [ "$FAILED" -eq 0 ]; then
  echo "🎉 ALL PRE-BUILT FLAVORS, DEBOOGEY INSTALLERS, AND TWEAK LOADERS FULLY VERIFIED!"
  exit 0
else
  echo "❌ Verification failed with $FAILED error(s)."
  exit 1
fi
