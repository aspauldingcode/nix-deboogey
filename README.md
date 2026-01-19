# nix-deboogey

A Nix flake providing **Deboogey** (Ammonia + Nix) in macOS Tart VMs for ARM-based Macs.

## One Command, Everything Ready

```bash
nix run github:aspauldingcode/nix-deboogey#tahoe
```

That's it! This single command:

- 📦 **Smart clones** the prebuilt VM (skips if already exists)
- 🚀 **Starts the VM** with your home directory shared
- 📁 **Sets up shared folders** at `/Volumes/My Shared Files`
- 📋 **Displays connection info** (IP, SSH, SFTP commands)

Just run it and you're ready to develop!

## Available VMs

| Command | macOS Version |
|---------|---------------|
| `nix run github:aspauldingcode/nix-deboogey#tahoe` | macOS 26.0 (Tahoe) |
| `nix run github:aspauldingcode/nix-deboogey#sequoia` | macOS 15.0 (Sequoia) |
| `nix run github:aspauldingcode/nix-deboogey#sonoma` | macOS 14.0 (Sonoma) |
| `nix run github:aspauldingcode/nix-deboogey#ventura` | macOS 13.0 (Ventura) |
| `nix run github:aspauldingcode/nix-deboogey#monterey` | macOS 12.0 (Monterey) |

## Use as a Flake Input

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-deboogey.url = "github:aspauldingcode/nix-deboogey";
  };

  outputs = { self, nixpkgs, nix-deboogey }: {
    # Re-export the unified runner
    packages.aarch64-darwin.tahoe = nix-deboogey.packages.aarch64-darwin.tahoe;
    
    # Or access VM configs for custom setups
    vmConfigs = nix-deboogey.lib.aarch64-darwin.vmConfigs;
  };
}
```

Then your users can simply run:
```bash
nix run .#tahoe
```

## What's Included

Each prebuilt VM comes with:
- **Nix** package manager
- **Ammonia** macOS tweak environment  
- **Deboogey** development tools

## Requirements

- Apple Silicon Mac (aarch64-darwin)
- Nix with flakes enabled

## Maintainer Commands

<details>
<summary>Creating and pushing prebuilt VMs</summary>

```bash
# Enter dev shell (sets up credentials)
nix develop

# Create and push a prebuilt (pushes by default)
nix run .#create-prebuilt-tahoe

# Create without pushing
nix run .#create-prebuilt-tahoe -- --no-push
```

</details>

## License

MIT
