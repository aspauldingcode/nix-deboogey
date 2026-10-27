# nix-deboogey

Deboogey Tart VMs for nix-darwin. CI publishes the images. You enable the ones to install.

```nix
{
  inputs.nix-deboogey.url = "github:aspauldingcode/nix-deboogey";

  outputs = { self, nix-darwin, nix-deboogey, ... }: {
    darwinConfigurations.mac = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        nix-deboogey.darwinModules.default
        {
          nix-deboogey.vms.tahoe.enable = true;
          nix-deboogey.vms.ventura.enable = true;
        }
      ];
    };
  };
}
```

`darwin-rebuild switch` installs Tart from this flake and clones each enabled prebuilt. The same switch works for `golden-gate`, `sequoia`, `sonoma`, and `monterey`.

`nix run github:aspauldingcode/nix-deboogey#ventura` opens that VM. Tart is already in the app. `--headless` skips the window.

Guide: [https://aspauldingcode.github.io/nix-deboogey/](https://aspauldingcode.github.io/nix-deboogey/)

[View All Prebuilts](https://github.com/aspauldingcode/nix-deboogey/packages)
