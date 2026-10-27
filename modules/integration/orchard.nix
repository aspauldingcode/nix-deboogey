{ config, lib, pkgs, ... }:

let
  cfg = config.nix-deboogey.orchard;
  tartCfg = config.nix-deboogey.tart;

  orchardPkg = pkgs.orchard or null;
  orchardBin = if orchardPkg != null then "${orchardPkg}/bin/orchard" else "orchard";

  envVars = lib.optionalAttrs (cfg.licenseTier != "free") {
    ORCHARD_LICENSE_TIER = cfg.licenseTier;
  };
in
{
  options.nix-deboogey.orchard = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable Orchard VM orchestration.";
    };

    mode = lib.mkOption {
      type = lib.types.enum [ "dev" "controller" "worker" "none" ];
      default = "dev";
      description = "Orchard runtime mode: 'dev' (local launchd), 'controller', 'worker', or 'none'.";
    };

    controllerUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Controller URL required when running in 'worker' mode.";
    };

    workerName = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName or "tart-worker";
      description = "Node name registered with Orchard controller in worker mode.";
    };

    licenseTier = lib.mkOption {
      type = lib.types.enum [ "free" "gold" "platinum" ];
      default = "free";
      description = "Orchard licensing tier (free, gold, platinum).";
    };
  };

  config = lib.mkIf (tartCfg.enable && cfg.enable && cfg.mode != "none") {
    # Provide Orchard package when available in nixpkgs
    environment.systemPackages = lib.optional (orchardPkg != null) orchardPkg;

    # Allow unfree license for orchard & tart
    nixpkgs.config.allowUnfreePredicate = lib.mkDefault (pkg:
      builtins.elem (lib.getName pkg) [ "orchard" "tart" ]
    );

    # Shell aliases for Orchard interaction
    environment.shellAliases = {
      orchard-ssh = "orchard ssh";
      orchard-vnc = "orchard vnc";
    };

    # launchd agent for Orchard modes
    launchd.user.agents = {
      orchard-dev = lib.mkIf (cfg.mode == "dev") {
        command = "${orchardBin} dev";
        serviceConfig = {
          RunAtLoad = true;
          KeepAlive = true;
          StandardOutPath = "/tmp/orchard-dev.log";
          StandardErrorPath = "/tmp/orchard-dev.error.log";
          EnvironmentVariables = envVars;
        };
      };

      orchard-controller = lib.mkIf (cfg.mode == "controller") {
        command = "${orchardBin} controller";
        serviceConfig = {
          RunAtLoad = true;
          KeepAlive = true;
          StandardOutPath = "/tmp/orchard-controller.log";
          StandardErrorPath = "/tmp/orchard-controller.error.log";
          EnvironmentVariables = envVars;
        };
      };

      orchard-worker = lib.mkIf (cfg.mode == "worker") {
        command =
          let
            controllerArg = if cfg.controllerUrl != null then "--controller ${cfg.controllerUrl}" else "";
          in
          "${orchardBin} worker ${controllerArg} --name ${cfg.workerName}";
        serviceConfig = {
          RunAtLoad = true;
          KeepAlive = true;
          StandardOutPath = "/tmp/orchard-worker.log";
          StandardErrorPath = "/tmp/orchard-worker.error.log";
          EnvironmentVariables = envVars;
        };
      };
    };
  };
}
