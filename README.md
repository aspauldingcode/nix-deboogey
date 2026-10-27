# nix-deboogey

macOS [Tart](https://tart.run/) VMs with [Deboogey](https://github.com/theoderoy/Deboogey) already installed. Monterey through Golden Gate. Apple Silicon only. SIP is changed inside the guest, not on your Mac.

**Guide:** [https://aspauldingcode.github.io/nix-deboogey/](https://aspauldingcode.github.io/nix-deboogey/) ([docs/index.html](docs/index.html))

**[View All Prebuilts](https://github.com/aspauldingcode/nix-deboogey/packages)**

## Run one

```bash
nix run github:aspauldingcode/nix-deboogey#tahoe -- --gui
nix run github:aspauldingcode/nix-deboogey#ventura
nix run github:aspauldingcode/nix-deboogey            # Sequoia
```

Same apps exist for `golden-gate`, `sequoia`, `sonoma`, and `monterey`, plus an `ephemeral-` prefix (`#ephemeral-tahoe`). The VM is deleted when the command exits.

## Declare one

```nix
nix-deboogey.url = "github:aspauldingcode/nix-deboogey";

# modules = [ nix-deboogey.darwinModules.default { nix-deboogey.tart.vms = [ "sequoia" "tahoe" ]; } ];
```

`darwin-rebuild switch` pulls `ghcr.io/aspauldingcode/nix-deboogey/macos-<name>-deboogey:latest` and clones a local VM named `<name>-deboogey`. It does not boot that VM unless `autoStart = true`.

CPU, memory, disk, networking, and shared folders are in the guide.
