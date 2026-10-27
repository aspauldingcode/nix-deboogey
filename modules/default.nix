{ config, lib, pkgs, ... }:

let
  cfg = config.nix-deboogey.tart;

  # Shared folder type for defaults
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

  # Resolve primary user home for default home share
  resolveHome =
    let
      users = config.users.users or {};
      primaryUser = config.users.primaryUser or "admin";
      userConfig = users.${primaryUser} or {};
    in
    userConfig.home or "/Users/${primaryUser}";

  # Resolve Tart executable
  tartPkg = pkgs.tart or null;
  tartBin =
    if !cfg.useHomebrewTart && tartPkg != null then
      "${cfg.package}/bin/tart"
    else
      "tart";
in
{
  imports = [
    ./integration/shared-folders.nix
    ./integration/networking.nix
    ./integration/orchard.nix
    ./integration/ci-scaffolds.nix
    ./integration/ssh-helpers.nix
    ./integration/guest-agent.nix
  ];

  options.nix-deboogey.tart = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable nix-deboogey Tart VM management.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default =
        if pkgs ? tart then
          pkgs.tart
        else
          throw "pkgs.tart unavailable; set nix-deboogey.tart.useHomebrewTart = true";
      description = "Tart package. Defaults to pkgs.tart when available.";
    };

    useHomebrewTart = lib.mkOption {
      type = lib.types.bool;
      default = !(pkgs ? tart);
      description = "Fall back to Homebrew cirruslabs/cli/tart when pkgs.tart is missing.";
    };

    # Global defaults inherited by every VM unless overridden
    defaults = {
      cpu = lib.mkOption {
        type = lib.types.int;
        default = 4;
        description = "Default number of CPUs allocated per VM.";
      };

      memory = lib.mkOption {
        type = lib.types.int;
        default = 8;
        description = "Default RAM in Gigabytes allocated per VM.";
      };

      diskSize = lib.mkOption {
        type = lib.types.int;
        default = 50;
        description = "Default disk size in Gigabytes per VM.";
      };

      net = lib.mkOption {
        type = lib.types.enum [ "shared" "bridged" "host-only" "softnet" ];
        default = "shared";
        description = "Default networking mode (shared NAT, bridged, host-only, softnet).";
      };

      bridgedInterface = lib.mkOption {
        type = lib.types.str;
        default = "en0";
        description = "Host network interface to bridge when net = 'bridged'.";
      };

      softnetPorts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Port mappings when net = 'softnet'.";
      };

      softnetAllow = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Allowed CIDR blocks when net = 'softnet'.";
      };

      softnetBlock = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Blocked CIDR blocks when net = 'softnet'.";
      };

      sharedFolders = lib.mkOption {
        type = lib.types.listOf sharedFolderType;
        default = [];
        description = "Default shared folders via VirtioFS.";
      };

      enableHomeShare = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to automatically share host home directory.";
      };

      ssh = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable SSH helper functions and sshpass.";
        };
        user = lib.mkOption {
          type = lib.types.str;
          default = "admin";
          description = "Default SSH user inside the guest VM.";
        };
        password = lib.mkOption {
          type = lib.types.str;
          default = "admin";
          description = "Default SSH password inside the guest VM.";
        };
      };

      guestAgent = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Tart guest agent integration.";
      };

      headless = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Default headless mode for persistent VMs (GUI enabled by default).";
      };

      autoStart = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to launch the VM automatically via launchd at login.";
      };
    };

    vms = lib.mkOption {
      type = lib.types.listOf (
        lib.types.coercedTo lib.types.str
          (name: { inherit name; })
          (lib.types.submodule (import ./vm-submodule.nix { inherit (cfg) defaults; }))
      );
      default = [];
      example = [ "macos-sequoia" "macos-tahoe" ];
      description = "List of Tart VMs to provision. String names coerce to VM submodules inheriting defaults.";
    };

    autoPull = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to pull the latest image during system activation.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Guard: Apple Silicon host required
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.isAarch64 && pkgs.stdenv.hostPlatform.isDarwin;
        message = "nix-deboogey: Tart VMs require an Apple Silicon Mac (aarch64-darwin).";
      }
    ];

    # Install Tart via nixpkgs or Homebrew
    environment.systemPackages = lib.optional (!cfg.useHomebrewTart && tartPkg != null) cfg.package;

    homebrew = {
      enable = lib.mkDefault true;
      taps = [ "cirruslabs/cli" ];
      brews = lib.optional cfg.useHomebrewTart "cirruslabs/cli/tart";
    };

    # System activation script to pull, clone, and configure each VM idempotently
    system.activationScripts.nix-deboogey-tart-vms.text = ''
      echo "==> Configuring nix-deboogey Tart VMs..."

      if command -v tart >/dev/null 2>&1; then
        TART_CMD="tart"
      elif [ -x "/opt/homebrew/bin/tart" ]; then
        TART_CMD="/opt/homebrew/bin/tart"
      elif [ -n "${tartPkg}" ] && [ -x "${tartPkg}/bin/tart" ]; then
        TART_CMD="${tartPkg}/bin/tart"
      else
        echo "Tart CLI not yet available in PATH during activation; will configure on next activation."
        TART_CMD=""
      fi

      if [ -n "$TART_CMD" ]; then
        ${lib.concatMapStrings (vm: ''
          echo "Processing VM: ${vm.localName} (${vm.source})..."
          ${lib.optionalString cfg.autoPull ''
            "$TART_CMD" pull "${vm.source}" || true
          ''}

          # Clone VM if not already present
          if ! "$TART_CMD" list 2>/dev/null | grep -E "^${vm.localName}[[:space:]]" >/dev/null 2>&1; then
            echo "Cloning ${vm.source} -> ${vm.localName}..."
            "$TART_CMD" clone "${vm.source}" "${vm.localName}" 2>/dev/null || true
          else
            echo "Local VM ${vm.localName} already exists."
          fi

          # Idempotent disk resize check (J.7)
          CURRENT_DISK=$("$TART_CMD" get "${vm.localName}" --format json 2>/dev/null | grep -o '"diskSize":[^,}]*' | tr -dc '0-9' || echo "0")
          if [ -n "$CURRENT_DISK" ] && [ "$CURRENT_DISK" -lt "${toString vm.diskSize}" ]; then
            echo "Resizing ${vm.localName} disk from ''${CURRENT_DISK}GB to ${toString vm.diskSize}GB..."
            "$TART_CMD" set "${vm.localName}" --disk-size "${toString vm.diskSize}" 2>/dev/null || true
          fi

          # Tune CPU and Memory settings
          "$TART_CMD" set "${vm.localName}" --cpu "${toString vm.cpu}" --memory "${toString (vm.memory * 1024)}" 2>/dev/null || true
        '') cfg.vms}
      fi
    '';

    # Register launchd user agent service for persistent VMs
    launchd.user.agents = lib.listToAttrs (map (vm:
      let
        effectiveShares =
          vm.sharedFolders
          ++ lib.optional (vm.enableHomeShare && !(lib.any (s: s.name == "home") vm.sharedFolders)) {
            name = "home";
            path = resolveHome;
            ro = false;
          };

        shareFlags = lib.concatMapStringsSep " " (s: "--dir=${s.name}:${s.path}${lib.optionalString s.ro ":ro"}") effectiveShares;

        netFlags =
          if vm.net == "bridged" then "--net-bridged=${vm.bridgedInterface}"
          else if vm.net == "host-only" then "--net-host-only"
          else if vm.net == "softnet" then "--net-softnet ${lib.concatMapStringsSep " " (p: "--net-softnet-port=${p}") vm.softnetPorts}"
          else "";

        graphicsFlag = if vm.headless then "--no-graphics" else "";

        fullCmd = lib.concatStringsSep " " (lib.filter (s: s != "") [
          tartBin
          "run"
          vm.localName
          shareFlags
          netFlags
          graphicsFlag
        ]);
      in
      {
        name = "tart-${vm.localName}";
        value = {
          command = fullCmd;
          serviceConfig = {
            RunAtLoad = vm.autoStart;
            KeepAlive = false;
            StandardOutPath = "/tmp/tart-${vm.localName}.log";
            StandardErrorPath = "/tmp/tart-${vm.localName}.error.log";
          };
        };
      }
    ) cfg.vms);
  };
}
