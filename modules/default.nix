{ config, lib, pkgs, ... }:

let
  cfg = config.nix-deboogey.tart;

  versionMap = {
    "macos-golden-gate" = "golden-gate";
    "macos-tahoe"       = "tahoe";
    "macos-sequoia"     = "sequoia";
    "macos-sonoma"      = "sonoma";
    "macos-ventura"     = "ventura";
    "macos-monterey"    = "monterey";
  };
in
{
  options.nix-deboogey.tart = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.vms != [];
      description = "Whether to enable nix-deboogey Tart VM provisioning.";
    };

    vms = lib.mkOption {
      type = lib.types.listOf (lib.types.enum (builtins.attrNames versionMap));
      default = [];
      example = [ "macos-sequoia" "macos-tahoe" ];
      description = "List of Deboogey-infused macOS Tart VMs to provision declaratively.";
    };

    autoPull = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to pull the latest image during system activation.";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.vms != []) {
    # Guard: Tart only runs on Apple Silicon macOS hosts
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.isAarch64 && pkgs.stdenv.hostPlatform.isDarwin;
        message = "nix-deboogey: Tart VMs require an Apple Silicon Mac (aarch64-darwin).";
      }
    ];

    # Ensure Homebrew and Tart formula are configured
    homebrew = {
      enable = lib.mkDefault true;
      taps = [ "cirruslabs/cli" ];
      brews = [ "cirruslabs/cli/tart" ];
    };

    # Declarative activation script to pull and clone VMs idempotently
    system.activationScripts.nix-deboogey-tart-vms.text = ''
      echo "==> Configuring nix-deboogey Tart VMs..."
      if command -v tart >/dev/null 2>&1; then
        TART_CMD="tart"
      elif [ -x "/opt/homebrew/bin/tart" ]; then
        TART_CMD="/opt/homebrew/bin/tart"
      else
        echo "Tart CLI not yet available in PATH during activation; will retry on next activation."
        TART_CMD=""
      fi

      if [ -n "$TART_CMD" ]; then
        ${lib.concatMapStrings (vm: let
          codename = versionMap.${vm};
          image = "ghcr.io/aspauldingcode/nix-deboogey/macos-${codename}-deboogey:latest";
          localVm = "${vm}-deboogey";
        in ''
          echo "Processing VM: ${localVm} (${image})..."
          ${lib.optionalString cfg.autoPull ''
            "$TART_CMD" pull "${image}" || true
          ''}
          if ! "$TART_CMD" list 2>/dev/null | grep -E "^${localVm}[[:space:]]" >/dev/null 2>&1; then
            echo "Cloning ${image} -> ${localVm}..."
            "$TART_CMD" clone "${image}" "${localVm}" 2>/dev/null || true
          else
            echo "Local VM ${localVm} already exists; skipping clone."
          fi
        '') cfg.vms}
      fi
    '';
  };
}
