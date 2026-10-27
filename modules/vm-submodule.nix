{ defaults }:
{ config, lib, ... }:

let
  versionMap = {
    "macos-golden-gate" = "golden-gate";
    "macos-tahoe"       = "tahoe";
    "macos-sequoia"     = "sequoia";
    "macos-sonoma"      = "sonoma";
    "macos-ventura"     = "ventura";
    "macos-monterey"    = "monterey";
  };

  sharedFolderType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Share tag name visible to the guest VM.";
      };
      path = lib.mkOption {
        type = lib.types.str;
        description = "Host directory path to share.";
      };
      ro = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Mount directory as read-only in the guest.";
      };
    };
  };
in
{
  options = {
    name = lib.mkOption {
      type = lib.types.str;
      description = "Identifier for the Tart VM (e.g. 'macos-sequoia').";
    };

    localName = lib.mkOption {
      type = lib.types.str;
      default = "${config.name}-deboogey";
      description = "Local Tart VM name.";
    };

    source = lib.mkOption {
      type = lib.types.str;
      default =
        let
          codename = versionMap.${config.name} or config.name;
        in
        "ghcr.io/aspauldingcode/nix-deboogey/macos-${codename}-deboogey:latest";
      description = "OCI image URL to pull from.";
    };

    cpu = lib.mkOption {
      type = lib.types.int;
      default = defaults.cpu;
      description = "Number of CPU cores allocated to the VM.";
    };

    memory = lib.mkOption {
      type = lib.types.int;
      default = defaults.memory;
      description = "Memory allocated to the VM in Gigabytes.";
    };

    diskSize = lib.mkOption {
      type = lib.types.int;
      default = defaults.diskSize;
      description = "Disk size in Gigabytes.";
    };

    net = lib.mkOption {
      type = lib.types.enum [ "shared" "bridged" "host-only" "softnet" ];
      default = defaults.net;
      description = "Tart networking mode: shared (NAT), bridged, host-only, or softnet.";
    };

    bridgedInterface = lib.mkOption {
      type = lib.types.str;
      default = defaults.bridgedInterface;
      description = "Host network interface to bridge when net = 'bridged'.";
    };

    softnetPorts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = defaults.softnetPorts;
      description = "Port mappings when net = 'softnet' (e.g. ['8080:80']).";
    };

    softnetAllow = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = defaults.softnetAllow;
      description = "Allowed CIDR blocks when net = 'softnet'.";
    };

    softnetBlock = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = defaults.softnetBlock;
      description = "Blocked CIDR blocks when net = 'softnet'.";
    };

    ports = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Port forwarding rules.";
    };

    sharedFolders = lib.mkOption {
      type = lib.types.listOf sharedFolderType;
      default = defaults.sharedFolders;
      description = "List of host directories shared with the guest via VirtioFS.";
    };

    enableHomeShare = lib.mkOption {
      type = lib.types.bool;
      default = defaults.enableHomeShare;
      description = "Whether to automatically share the host user's home directory.";
    };

    headless = lib.mkOption {
      type = lib.types.bool;
      default = defaults.headless;
      description = "Whether to run without GUI (--no-graphics).";
    };

    guestAgent = lib.mkOption {
      type = lib.types.bool;
      default = defaults.guestAgent;
      description = "Whether Tart guest agent integration is expected/enabled.";
    };

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = defaults.autoStart;
      description = "Whether to launch the VM automatically via launchd at login.";
    };
  };
}
