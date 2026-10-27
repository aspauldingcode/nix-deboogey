# Creating Prebuilt VMs

This document describes how the prebuilt VMs are created and maintained.

## What's Included

Each prebuilt VM contains:

| Component | Source | Location |
|-----------|--------|----------|
| **Xcode** | Cirrus Labs base | `/Applications/Xcode.app` |
| **Determinate Nix** | [determinate.systems](https://install.determinate.systems/determinate-pkg/stable/Universal) | `/nix/*` |
| **Ammonia Injector** | [CoreBedtime/ammonia v1.5](https://github.com/CoreBedtime/ammonia/releases/tag/1.5) | System-wide |
| **Deboogey** | [theoderoy/Deboogey v1.1](https://github.com/theoderoy/Deboogey/releases/tag/rel-1.1) | `/Applications/Deboogey.app` |
| **Guest Flake** | Generated | `~/Desktop/nix-deboogey/flake.nix` |

## Available Prebuilts

| Image | macOS Version |
|-------|---------------|
| `ghcr.io/aspauldingcode/deboogey-tahoe:latest` | 26.0 (Tahoe) |
| `ghcr.io/aspauldingcode/deboogey-sequoia:latest` | 15.0 (Sequoia) |
| `ghcr.io/aspauldingcode/deboogey-sonoma:latest` | 14.0 (Sonoma) |
| `ghcr.io/aspauldingcode/deboogey-ventura:latest` | 13.0 (Ventura) |
| `ghcr.io/aspauldingcode/deboogey-monterey:latest` | 12.0 (Monterey) |

## Creating Prebuilts (Maintainer)

### Prerequisites

1. **GitHub PAT** with `write:packages` scope:
   ```bash
   export GITHUB_TOKEN=ghp_...
   ```

2. **Disk space**: ~100GB per VM

3. **Time**: ~30-60 minutes per VM (download + provision + upload)

### Steps

```bash
# 1. Authenticate to GHCR
nix run .#login-ghcr

# 2. Create and push a single prebuilt
nix run .#create-prebuilt-tahoe -- --push

# Or create all prebuilts
nix run .#create-prebuilt-all -- --push
```

### What Happens

1. **Clone**: Base VM cloned from Cirrus Labs (`macos-*-xcode`)
2. **Boot**: VM started headless
3. **Provision**: SSH into VM, run `provision-vm.sh`
4. **Stop**: VM gracefully shut down
5. **Push**: VM pushed to `ghcr.io/aspauldingcode/deboogey-*`

## Updating Prebuilts

To update an existing prebuilt:

```bash
# Clone the existing prebuilt
tart clone ghcr.io/aspauldingcode/deboogey-tahoe:latest deboogey-tahoe-update

# Run and make changes
tart run deboogey-tahoe-update

# Stop and push with new tag
tart stop deboogey-tahoe-update
tart push deboogey-tahoe-update ghcr.io/aspauldingcode/deboogey-tahoe:2026-01-18
tart push deboogey-tahoe-update ghcr.io/aspauldingcode/deboogey-tahoe:latest
```

## Provisioning Script

The [`scripts/provision-vm.sh`](../scripts/provision-vm.sh) script:

1. Downloads and installs Determinate Nix via `.pkg`
2. Downloads and installs Ammonia via `.pkg`
3. Downloads Deboogey `.aar`, extracts to `/Applications/Deboogey.app`
4. Creates guest flake at `~/Desktop/nix-deboogey/flake.nix`
5. Cleans up caches

## Guest Flake

The guest flake inside each VM provides:

```bash
# Launch Deboogey
nix run ~/Desktop/nix-deboogey#deboogey
```

## Troubleshooting

### Push fails with authentication error

```bash
# Re-authenticate
nix run .#login-ghcr
```

### VM fails to boot

Check Tart logs and ensure you have enough disk space:
```bash
tart list
df -h
```

### Provisioning fails

SSH into the VM manually and check:
```bash
nix run .#ssh-tahoe
cat /tmp/provision.log  # if exists
```
