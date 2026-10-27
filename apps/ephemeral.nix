{ pkgs }:

version:
let
  # Strip "macos-" prefix if passed as e.g. "macos-tahoe"
  cleanVersion = builtins.replaceStrings [ "macos-" ] [ "" ] version;
  image = "ghcr.io/aspauldingcode/nix-deboogey/macos-${cleanVersion}-deboogey:latest";

  script = pkgs.writeShellScriptBin "ephemeral-${version}" ''
    set -euo pipefail

    VERSION="${cleanVersion}"
    IMAGE="${image}"
    TMP_VM="ephemeral-''${VERSION}-$$"
    DEFAULT_DISK_SIZE=50
    DEFAULT_CPU=4
    DEFAULT_MEMORY=8192

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

    echo "--> Configuring default ephemeral resources (CPU: ''${DEFAULT_CPU}, RAM: ''${DEFAULT_MEMORY}MB, Disk: ''${DEFAULT_DISK_SIZE}GB)..."
    "$TART_CMD" set "''${TMP_VM}" --cpu "''${DEFAULT_CPU}" --memory "''${DEFAULT_MEMORY}" 2>/dev/null || true
    "$TART_CMD" set "''${TMP_VM}" --disk-size "''${DEFAULT_DISK_SIZE}" 2>/dev/null || true

    echo "--> Starting ''${TMP_VM} (ephemeral, headless by default)..."
    # Ephemeral runner runs headless by default unless --gui is specified in arguments
    if [ $# -gt 0 ]; then
      RUN_ARGS=()
      for arg in "$@"; do
        if [ "$arg" = "--gui" ]; then
          # Skip adding --no-graphics if --gui was requested
          true
        else
          RUN_ARGS+=("$arg")
        fi
      done

      # Check if user explicitly asked for GUI or --no-graphics
      if [[ " $* " =~ " --gui " ]]; then
        exec "$TART_CMD" run "''${TMP_VM}" "''${RUN_ARGS[@]}"
      elif [[ " $* " =~ " --no-graphics " ]]; then
        exec "$TART_CMD" run "''${TMP_VM}" "''${RUN_ARGS[@]}"
      else
        exec "$TART_CMD" run "''${TMP_VM}" --no-graphics "''${RUN_ARGS[@]}"
      fi
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
