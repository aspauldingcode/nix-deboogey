{ pkgs, tart }:

version:
let
  image = "ghcr.io/aspauldingcode/nix-deboogey/macos-${version}-deboogey:latest";
  tartBin = "${tart}/bin/tart";

  script = pkgs.writeShellScriptBin "ephemeral-${version}" ''
    set -euo pipefail

    TART="${tartBin}"
    [ -x "$TART" ] || { echo "nix-deboogey: bundled Tart is missing" >&2; exit 1; }

    VM="ephemeral-${version}-$$"
    trap '"$TART" stop "$VM" 2>/dev/null || true; "$TART" delete "$VM" 2>/dev/null || true' EXIT INT TERM

    echo "==> Preparing Deboogey VM: $VM (${image})..."
    if ! "$TART" pull "${image}"; then
      echo "nix-deboogey: ${image} is not in GitHub Packages." >&2
      exit 1
    fi
    "$TART" clone "${image}" "$VM"
    "$TART" set "$VM" --cpu 4 --memory 8192 --disk-size 50 2>/dev/null || true

    # A window is the default. --headless is the opt-out.
    GRAPHICS=""
    SHARE_HOME="--dir=home:$HOME"
    ARGS=()
    for arg in "$@"; do
      if [ "$arg" = "--headless" ]; then GRAPHICS="--no-graphics";
      elif [ "$arg" = "--gui" ]; then GRAPHICS="";
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
