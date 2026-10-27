{
  description = "Deboogey Tart VMs for nix-darwin";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      versions = import ./versions.nix;
      each = lib.genAttrs [ "aarch64-darwin" "x86_64-darwin" ];
      runners = system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          mk = import ./apps/ephemeral.nix { inherit pkgs; };
        in
        lib.genAttrs versions (name: mk name);
    in
    {
      darwinModules.default = import ./modules/default.nix;

      apps = each (system:
        let built = runners system; in
        lib.mapAttrs (_: run: run.app) built // { default = built.sequoia.app; });

      packages = each (system:
        let built = runners system; in
        lib.mapAttrs (_: run: run.package) built // { default = built.sequoia.package; });
    };
}
