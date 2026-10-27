{ config, lib, pkgs, ... }:

let
  cfg = config.nix-deboogey.tart;

  # Helper to resolve user's home directory across various nix-darwin setups
  resolveHome =
    let
      users = config.users.users or {};
      primaryUser = config.users.primaryUser or "admin";
      userConfig = users.${primaryUser} or {};
    in
    userConfig.home or "/Users/${primaryUser}";

  # Helper function to generate --dir CLI arguments for a VM
  mkShareArgs = vm:
    let
      effectiveShares =
        vm.sharedFolders
        ++ lib.optional (vm.enableHomeShare && !(lib.any (s: s.name == "home") vm.sharedFolders)) {
          name = "home";
          path = resolveHome;
          ro = false;
        };
    in
    map (share: "--dir=${share.name}:${share.path}${lib.optionalString share.ro ":ro"}") effectiveShares;
in
{
  # Expose helper in lib/internal namespace if needed
  _module.args.mkShareArgs = mkShareArgs;
}
