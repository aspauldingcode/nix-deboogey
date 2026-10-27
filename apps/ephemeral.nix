{ pkgs }:

version:
let
  image = "ghcr.io/aspauldingcode/nix-deboogey/macos-${version}-deboogey:latest";

  script = pkgs.writeShellScriptBin "ephemeral-${version}" ''
    set -euo pipefail

    # Tart comes from PATH or Homebrew. The nix-darwin module installs it.
    if command -v tart >/dev/null 2>&1; then
      TART="tart"
    elif [ -x "/opt/homebrew/bin/tart" ]; then
      TART="/opt/homebrew/bin/tart"
    elif [ -x "/usr/local/bin/tart" ]; then
      TART="/usr/local/bin/tart"
    else
      echo "Error: Tart CLI not found. Install via 'brew install openai/tools/tart'." >&2
      exit 1
    fi

    VM="ephemeral-${version}-$$"
    trap '"$TART" stop "$VM" 2>/dev/null || true; "$TART" delete "$VM" 2>/dev/null || true' EXIT INT TERM

    echo "==> Preparing Deboogey VM: $VM (${image})..."
    "$TART" pull "${image}"
    "$TART" clone "${image}" "$VM"
    "$TART" set "$VM" --cpu 4 --memory 8192 --disk-size 50 2>/dev/null || true

    GRAPHICS="--no-graphics"
    SHARE_HOME="--dir=home:$HOME"
    ARGS=()
    for arg in "$@"; do
      if [ "$arg" = "--gui" ]; then GRAPHICS="";
      elif [ "$arg" = "--no-home" ]; then SHARE_HOME="";
      else ARGS+=("$arg"); fi
    done

    echo "==> Launching $VM with Deboogey pre-installed..."
    exec "$TART" run "$VM" $GRAPHICS $SHARE_HOME "''${ARGS[@]}"
  '';
in
{
  app = { type = "app"; program = "${script}/bin/ephemeral-${version}"; };
  package = script;
}
