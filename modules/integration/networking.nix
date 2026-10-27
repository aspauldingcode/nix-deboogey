{ config, lib, pkgs, ... }:

let
  cfg = config.nix-deboogey.tart;

  # Helper function to generate Tart networking CLI arguments for a VM
  mkNetArgs = vm:
    if vm.net == "bridged" then
      [ "--net-bridged=${vm.bridgedInterface}" ]
    else if vm.net == "host-only" then
      [ "--net-host-only" ]
    else if vm.net == "softnet" then
      [ "--net-softnet" ]
      ++ (map (p: "--net-softnet-port=${p}") vm.softnetPorts)
    else
      # "shared" is Tart's default NAT networking
      [];
in
{
  _module.args.mkNetArgs = mkNetArgs;
}
