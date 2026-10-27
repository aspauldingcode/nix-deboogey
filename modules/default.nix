{ config, lib, pkgs, ... }:

let
  versions = import ../versions.nix;
  cfg = config.nix-deboogey.vms;
  enabled = lib.filter (name: cfg.${name}.enable) versions;
  autoStarted = lib.filter (name: cfg.${name}.autoStart) enabled;
  image = name: "ghcr.io/aspauldingcode/nix-deboogey/macos-${name}-deboogey:latest";
  home =
    if config.system.primaryUser == null
    then "/Users/admin"
    else config.system.primaryUserHome;
in
{
  options.nix-deboogey.vms = lib.genAttrs versions (name: lib.mkOption {
    default = { };
    description = "${name} Deboogey Tart VM";
    type = lib.types.submodule {
      options = {
        enable = lib.mkEnableOption "installation of the ${name} prebuilt";
        cpu = lib.mkOption { type = lib.types.int; default = 4; };
        memory = lib.mkOption { type = lib.types.int; default = 8; description = "Memory in GiB."; };
        diskSize = lib.mkOption { type = lib.types.int; default = 50; description = "Disk in GiB."; };
        autoStart = lib.mkOption { type = lib.types.bool; default = false; description = "Start the VM at login."; };
      };
    };
  });

  config = lib.mkIf (enabled != [ ]) {
    assertions = [{
      assertion = pkgs.stdenv.hostPlatform.isAarch64 && pkgs.stdenv.hostPlatform.isDarwin;
      message = "nix-deboogey needs an Apple Silicon Mac.";
    }];

    system.requiresPrimaryUser = lib.mkIf (autoStarted != [ ]) [ "nix-deboogey.vms" ];

    homebrew = {
      enable = lib.mkDefault true;
      taps = [ "openai/tools" "cirruslabs/cli" ];
      brews = [ "openai/tools/tart" "cirruslabs/cli/sshpass" ];
    };

    environment.interactiveShellInit = ''
      tart-ssh() {
        local vm="''${1:?vm name}" ip
        shift
        ip="$(tart ip "$vm" 2>/dev/null || true)"
        [ -n "$ip" ] || { echo "nix-deboogey: no IP for $vm" >&2; return 1; }
        sshpass -p admin ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "admin@$ip" "$@"
      }
    '';

    # Homebrew activation installs tart. This runs after it.
    system.activationScripts.postActivation.text = lib.mkAfter ''
      TART="$(command -v tart || true)"
      [ -x "$TART" ] || TART="/opt/homebrew/bin/tart"
      [ -x "$TART" ] || { echo "nix-deboogey: tart is not installed" >&2; exit 1; }
      ${lib.concatMapStrings (name: ''
        vm="${name}-deboogey"
        echo "nix-deboogey: installing $vm"
        "$TART" pull "${image name}"
        "$TART" list 2>/dev/null | awk '{print $1}' | grep -qx "$vm" || "$TART" clone "${image name}" "$vm"
        "$TART" set "$vm" --cpu ${toString cfg.${name}.cpu} --memory ${toString (cfg.${name}.memory * 1024)}
        "$TART" set "$vm" --disk-size ${toString cfg.${name}.diskSize} || echo "nix-deboogey: left $vm disk size unchanged"
      '') enabled}
    '';

    launchd.user.agents = lib.listToAttrs (map (name: {
      name = "tart-${name}-deboogey";
      value = {
        command = "/opt/homebrew/bin/tart run ${name}-deboogey --dir=home:${home}";
        serviceConfig = {
          RunAtLoad = true;
          KeepAlive = false;
          StandardOutPath = "/tmp/tart-${name}-deboogey.log";
          StandardErrorPath = "/tmp/tart-${name}-deboogey.err";
        };
      };
    }) autoStarted);
  };
}
