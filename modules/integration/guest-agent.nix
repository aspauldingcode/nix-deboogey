{ config, lib, pkgs, ... }:

let
  cfg = config.nix-deboogey.tart;

  # Helper to determine headless graphics flag for a VM
  mkGraphicsArgs = vm:
    if vm.headless then
      [ "--no-graphics" ]
    else
      [];
in
{
  _module.args.mkGraphicsArgs = mkGraphicsArgs;
}
