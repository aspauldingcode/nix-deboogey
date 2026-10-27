{ pkgs }:

version:
let
  image = "ghcr.io/aspauldingcode/nix-deboogey/macos-${version}-deboogey:latest";
  script = pkgs.writeShellScriptBin "ephemeral-${version}" ''
    set -euo pipefail

    VERSION="${version}"
    IMAGE="${image}"
    TMP_VM="ephemeral-''${VERSION}-$$"

    # Prefer PATH tart (e.g. from Homebrew) or fallback to nixpkgs tart
    if command -v tart >/dev/null 2>&1; then
      TART_CMD="tart"
    elif [ -x "${pkgs.tart or ""}/bin/tart" ]; then
      TART_CMD="${pkgs.tart}/bin/tart"
    else
      echo "❌ Error: Tart CLI not found in PATH or nixpkgs."
      echo "Please install Tart via 'brew install cirruslabs/cli/tart' or enable unfree nixpkgs."
      exit 1
    fi

    echo "=========================================================="
    echo " Launching Ephemeral Tart VM: ''${TMP_VM}"
    echo " Source OCI image: ''${IMAGE}"
    echo "=========================================================="

    cleanup() {
      echo ""
      echo "==> Cleaning up ephemeral VM ''${TMP_VM}..."
      "$TART_CMD" stop "''${TMP_VM}" 2>/dev/null || true
      "$TART_CMD" delete "''${TMP_VM}" 2>/dev/null || true
      echo "==> Ephemeral VM destroyed. No persistent state remains."
    }
    trap cleanup EXIT INT TERM

    echo "--> Pulling latest image if needed..."
    "$TART_CMD" pull "''${IMAGE}"

    echo "--> Cloning ephemeral instance..."
    "$TART_CMD" clone "''${IMAGE}" "''${TMP_VM}"

    echo "--> Starting ''${TMP_VM}..."
    if [ $# -gt 0 ]; then
      exec "$TART_CMD" run "''${TMP_VM}" "$@"
    else
      exec "$TART_CMD" run "''${TMP_VM}" --no-graphics
    fi
  '';
in
{
  app = {
    type = "app";
    program = "${script}/bin/ephemeral-${version}";
  };
  package = script;
}
