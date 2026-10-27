{
  description = "Nix flake for Deboogey Tart VMs with nix-darwin module and ephemeral runners";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-darwin } @ inputs:
    let
      supportedSystems = [ "aarch64-darwin" "x86_64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);

      mkPkgs = system: import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true; # Required for Tart CLI (Fair Source License)
        };
      };

      supportedVersions = [
        "golden-gate"
        "tahoe"
        "sequoia"
        "sonoma"
        "ventura"
        "monterey"
      ];

      mkEphemeral = pkgs: import ./apps/ephemeral.nix { inherit pkgs; };
    in
    {
      # =========================================================================
      # nix-darwin Modules
      # =========================================================================
      darwinModules = {
        default = import ./modules/default.nix;
        nix-deboogey = self.darwinModules.default;
      };

      # =========================================================================
      # Ephemeral Runner Apps
      # =========================================================================
      apps = forAllSystems (system:
        let
          pkgs = mkPkgs system;
          ephemeral = mkEphemeral pkgs;
        in
        builtins.listToAttrs (map (ver: {
          name = "ephemeral-${ver}";
          value = (ephemeral ver).app;
        }) supportedVersions)
      );

      # =========================================================================
      # Packages (Underlying Derivations for Apps)
      # =========================================================================
      packages = forAllSystems (system:
        let
          pkgs = mkPkgs system;
          ephemeral = mkEphemeral pkgs;
        in
        builtins.listToAttrs (map (ver: {
          name = "ephemeral-${ver}";
          value = (ephemeral ver).package;
        }) supportedVersions)
      );

      # =========================================================================
      # Development Shell
      # =========================================================================
      devShells = forAllSystems (system:
        let
          pkgs = mkPkgs system;
        in
        {
          default = pkgs.mkShell {
            name = "nix-deboogey-dev";
            packages = with pkgs; [
              tart
              packer
              git
              gh
              curl
            ];

            shellHook = ''
              echo "Deboogey Tart VM pipeline development shell"
              echo "Available tools: tart, packer, git, gh"
            '';
          };
        }
      );
    };
}
