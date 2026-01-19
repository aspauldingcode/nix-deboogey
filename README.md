# nix-deboogey

A Nix flake providing **Deboogey** (Ammonia + Nix) in macOS Tart VMs for ARM-based Macs.

## Quick Start

```bash
# Run the Tahoe (macOS 26.0) VM with all features
nix run github:aspauldingcode/nix-deboogey#tahoe
```

This single command will:
- Clone the prebuilt VM from GHCR (skips if already exists)
- Start the VM with your home directory shared
- Display connection info (SSH, SFTP)

## Available VMs

| Command | macOS Version |
|---------|---------------|
| `nix run .#tahoe` | macOS 26.0 (Tahoe) |
| `nix run .#sequoia` | macOS 15.0 (Sequoia) |
| `nix run .#sonoma` | macOS 14.0 (Sonoma) |
| `nix run .#ventura` | macOS 13.0 (Ventura) |
| `nix run .#monterey` | macOS 12.0 (Monterey) |

## Use as a Flake Input

Add to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-deboogey.url = "github:aspauldingcode/nix-deboogey";
  };

  outputs = { self, nixpkgs, nix-deboogey }: {
    # Access VM configs
    vmConfigs = nix-deboogey.lib.aarch64-darwin.vmConfigs;
    
    # Access packages
    packages.aarch64-darwin = {
      tahoe = nix-deboogey.packages.aarch64-darwin.tahoe;
    };
  };
}
```

## Manual Commands

```bash
# Clone a specific VM
nix run .#clone-tahoe

# Run with shared folder
nix run .#run-tahoe -- --dir=~

# SSH into running VM
nix run .#ssh-tahoe

# SFTP into running VM
nix run .#sftp-vm -- deboogey-tahoe
```

## Maintainer Commands

Create and push prebuilt VMs to GHCR:

```bash
# Enter dev shell (sets up credentials)
nix develop

# Create and push a prebuilt
nix run .#create-prebuilt-tahoe

# Create without pushing
nix run .#create-prebuilt-tahoe -- --no-push
```

## Requirements

- Apple Silicon Mac (aarch64-darwin)
- Nix with flakes enabled

## License

MIT
