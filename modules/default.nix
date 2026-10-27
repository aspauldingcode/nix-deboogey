{ config, lib, pkgs, ... }:

let
  cfg = config.nix-deboogey.tart;
  orchard = config.nix-deboogey.orchard;
  primaryUser = config.users.primaryUser or "admin";
  userHome = (config.users.users.${primaryUser} or {}).home or "/Users/${primaryUser}";

  vmSubmodule = lib.types.submodule ({ config = vm; ... }: {
    options = {
      name = lib.mkOption { type = lib.types.str; description = "VM identifier"; };
      localName = lib.mkOption { type = lib.types.str; default = "${vm.name}-deboogey"; };
      source = lib.mkOption {
        type = lib.types.str;
        default = "ghcr.io/aspauldingcode/nix-deboogey/macos-${lib.removePrefix "macos-" vm.name}-deboogey:latest";
      };
      cpu = lib.mkOption { type = lib.types.int; default = cfg.defaults.cpu; };
      memory = lib.mkOption { type = lib.types.int; default = cfg.defaults.memory; };
      diskSize = lib.mkOption { type = lib.types.int; default = cfg.defaults.diskSize; };
      net = lib.mkOption { type = lib.types.enum [ "shared" "bridged" "host-only" "softnet" ]; default = "shared"; };
      bridgedInterface = lib.mkOption { type = lib.types.str; default = "en0"; };
      softnetPorts = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; };
      enableHomeShare = lib.mkOption { type = lib.types.bool; default = true; };
      sharedFolders = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            name = lib.mkOption { type = lib.types.str; };
            path = lib.mkOption { type = lib.types.str; };
            ro = lib.mkOption { type = lib.types.bool; default = false; };
          };
        });
        default = [];
      };
      headless = lib.mkOption { type = lib.types.bool; default = false; };
      autoStart = lib.mkOption { type = lib.types.bool; default = false; };
    };
  });
in
{
  options.nix-deboogey = {
    tart = {
      enable = lib.mkEnableOption "nix-deboogey Tart VM management" // { default = true; };
      defaults = {
        cpu = lib.mkOption { type = lib.types.int; default = 4; };
        memory = lib.mkOption { type = lib.types.int; default = 8; };
        diskSize = lib.mkOption { type = lib.types.int; default = 50; };
      };
      vms = lib.mkOption {
        type = lib.types.listOf (lib.types.coercedTo lib.types.str (name: { inherit name; }) vmSubmodule);
        default = [];
        description = "Declarative Tart VMs. Strings coerce to standard Deboogey submodules.";
      };
      autoPull = lib.mkOption { type = lib.types.bool; default = true; };
    };
    orchard = {
      enable = lib.mkEnableOption "Orchard VM orchestration" // { default = false; };
      mode = lib.mkOption { type = lib.types.enum [ "dev" "controller" "worker" ]; default = "dev"; };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = pkgs.stdenv.hostPlatform.isAarch64 && pkgs.stdenv.hostPlatform.isDarwin;
      message = "nix-deboogey: Tart VMs require an Apple Silicon Mac (aarch64-darwin).";
    }];

    homebrew = {
      enable = lib.mkDefault true;
      taps = [ "cirruslabs/cli" ];
      brews = [ "cirruslabs/cli/tart" "cirruslabs/cli/sshpass" ];
    };

    environment.interactiveShellInit = ''
      tart-ssh() {
        local vm="$1"; shift
        local ip="$(tart ip "$vm" 2>/dev/null || true)"
        [ -z "$ip" ] && { echo "Cannot resolve IP for Tart VM '$vm'." >&2; return 1; }
        sshpass -p admin ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "admin@$ip" "$@"
      }
      tart-scp() {
        sshpass -p admin scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$@"
      }
    '';

    system.activationScripts.nix-deboogey-tart-vms.text = ''
      TART="$(command -v tart || echo "/opt/homebrew/bin/tart")"
      if [ -x "$TART" ]; then
        ${lib.concatMapStrings (vm: ''
          echo "==> Configuring Tart VM: ${vm.localName}..."
          ${lib.optionalString cfg.autoPull ''"$TART" pull "${vm.source}" 2>/dev/null || true''}
          if ! "$TART" list 2>/dev/null | grep -E "^${vm.localName}[[:space:]]" >/dev/null; then
            "$TART" clone "${vm.source}" "${vm.localName}" 2>/dev/null || true
          fi
          CURRENT_DISK=$("$TART" get "${vm.localName}" --format json 2>/dev/null | grep -o '"diskSize":[^,}]*' | tr -dc '0-9' || echo "0")
          if [ -n "$CURRENT_DISK" ] && [ "$CURRENT_DISK" -lt "${toString vm.diskSize}" ]; then
            "$TART" set "${vm.localName}" --disk-size "${toString vm.diskSize}" 2>/dev/null || true
          fi
          "$TART" set "${vm.localName}" --cpu "${toString vm.cpu}" --memory "${toString (vm.memory * 1024)}" 2>/dev/null || true
        '') cfg.vms}
      fi
    '';

    launchd.user.agents = lib.listToAttrs (map (vm:
      let
        shares = vm.sharedFolders ++ lib.optional vm.enableHomeShare { name = "home"; path = userHome; ro = false; };
        shareFlags = lib.concatMapStringsSep " " (s: "--dir=${s.name}:${s.path}${lib.optionalString s.ro ":ro"}") shares;
        netFlags =
          if vm.net == "bridged" then "--net-bridged=${vm.bridgedInterface}"
          else if vm.net == "host-only" then "--net-host-only"
          else if vm.net == "softnet" then "--net-softnet ${lib.concatMapStringsSep " " (p: "--net-softnet-port=${p}") vm.softnetPorts}"
          else "";
        gfxFlag = lib.optionalString vm.headless "--no-graphics";
      in {
        name = "tart-${vm.localName}";
        value = {
          command = "tart run ${vm.localName} ${shareFlags} ${netFlags} ${gfxFlag}";
          serviceConfig = {
            RunAtLoad = vm.autoStart;
            KeepAlive = false;
            StandardOutPath = "/tmp/tart-${vm.localName}.log";
            StandardErrorPath = "/tmp/tart-${vm.localName}.error.log";
          };
        };
      }
    ) cfg.vms) // lib.optionalAttrs orchard.enable {
      orchard = {
        command = "orchard ${orchard.mode}";
        serviceConfig = { RunAtLoad = true; KeepAlive = true; };
      };
    };
  };
}
