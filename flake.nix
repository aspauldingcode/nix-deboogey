{
  description = "Turnkey Deboogey Tart VMs: declarative nix-darwin module & one-command runners";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-darwin }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      versions = [ "golden-gate" "tahoe" "sequoia" "sonoma" "ventura" "monterey" ];
    in {
      darwinModules.default = import ./modules/default.nix;
      darwinModules.nix-deboogey = self.darwinModules.default;

      apps = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          runner = import ./apps/ephemeral.nix { inherit pkgs; };
          appsMap = builtins.listToAttrs (builtins.concatMap (v: [
            { name = "ephemeral-${v}"; value = (runner v).app; }
            { name = v;               value = (runner v).app; }
          ]) versions);
        in appsMap // { default = (runner "sequoia").app; }
      );

      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          runner = import ./apps/ephemeral.nix { inherit pkgs; };
          pkgMap = builtins.listToAttrs (builtins.concatMap (v: [
            { name = "ephemeral-${v}"; value = (runner v).package; }
            { name = v;               value = (runner v).package; }
          ]) versions);
        in pkgMap // { default = (runner "sequoia").package; }
      );

      devShells = forAllSystems (system: {
        default = nixpkgs.legacyPackages.${system}.mkShell {
          packages = with nixpkgs.legacyPackages.${system}; [ packer git gh curl ];
        };
      });
    };
}
