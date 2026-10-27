# nix-deboogey

Automated, reproducible pipeline producing custom macOS [Tart](https://tart.run/) virtual machines pre-installed with [Deboogey](https://github.com/theoderoy/Deboogey) and version-gated tweak loaders:
- **Ammonia** for macOS < 26 (Monterey, Ventura, Sonoma, Sequoia)
- **Plugin Playground** for macOS ≥ 26 (Tahoe, Golden Gate)

Images are built from Cirrus Labs `-vanilla` base images, published as public OCI artifacts to the GitHub Container Registry (`ghcr.io`), and consumed declaratively through a **nix-darwin module** or ephemerally via `nix run`.

---

## VM Matrix & Tweak Loader Architecture

| macOS Codename | Version Family | Base Vanilla OCI Image | Tweak Loader | SIP & Security Constraints |
| :--- | :--- | :--- | :--- | :--- |
| **Golden Gate** | ≥ 26 *(runtime verified)* | `ghcr.io/cirruslabs/macos-golden-gate-vanilla:latest` | Plugin Playground | **Full SIP disable** + `nvram boot-args=-arm64e_preview_abi` |
| **Tahoe** | 26 | `ghcr.io/cirruslabs/macos-tahoe-vanilla:latest` | Plugin Playground | **Full SIP disable** + `nvram boot-args=-arm64e_preview_abi` |
| **Sequoia** | 15 | `ghcr.io/cirruslabs/macos-sequoia-vanilla:latest` | Ammonia 1.5 | **Full SIP disable** + `nvram boot-args=-arm64e_preview_abi` |
| **Sonoma** | 14 | `ghcr.io/cirruslabs/macos-sonoma-vanilla:latest` | Ammonia 1.5 | **Full SIP disable** + `nvram boot-args=-arm64e_preview_abi` |
| **Ventura** | 13 | `ghcr.io/cirruslabs/macos-ventura-vanilla:latest` | Ammonia 1.5 | **Full SIP disable** + `nvram boot-args=-arm64e_preview_abi` |
| **Monterey** | 12 | `ghcr.io/cirruslabs/macos-monterey-vanilla:latest` | Ammonia 1.5 | **Full SIP disable** + `nvram boot-args=-arm64e_preview_abi` |

> [!WARNING]
> **Guest vs. Host Security Isolation**: Full SIP disablement (`csrutil disable`) and NVRAM boot arguments (`-arm64e_preview_abi`) are applied **exclusively inside the guest Tart VM**. Your macOS host system security and SIP remain 100% untouched.

---

## Quickstart: Ephemeral Runner (`nix run`)

Run an ephemeral VM that pulls the image, clones to a temporary VM instance, boots into Tart, and automatically stops and destroys the temporary VM on exit:

```bash
# Run Tahoe (macOS 26) with Plugin Playground & Deboogey
nix run github:aspauldingcode/nix-deboogey#ephemeral-tahoe

# Run Sequoia (macOS 15) with Ammonia & Deboogey
nix run github:aspauldingcode/nix-deboogey#ephemeral-sequoia

# Run with custom Tart flags (e.g. mounting a directory or GUI mode)
nix run github:aspauldingcode/nix-deboogey#ephemeral-tahoe -- --dir host_work:/Users/admin/work
```

Available ephemeral targets:
- `ephemeral-golden-gate`
- `ephemeral-tahoe`
- `ephemeral-sequoia`
- `ephemeral-sonoma`
- `ephemeral-ventura`
- `ephemeral-monterey`

---

## Declarative nix-darwin Integration

Add `nix-deboogey` to your nix-darwin flake inputs and enable the module to automatically manage Homebrew Tart installation and pull/clone your selected VMs during system activation (`darwin-rebuild switch`).

### `flake.nix` Example

```nix
{
  description = "Darwin system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    # nix-deboogey flake input
    nix-deboogey.url = "github:aspauldingcode/nix-deboogey";
    nix-deboogey.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nix-darwin, nix-deboogey }: {
    darwinConfigurations."My-Apple-Silicon-Mac" = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        nix-deboogey.darwinModules.default
        {
          # Select which VMs to provision
          nix-deboogey.tart.vms = [
            "macos-sequoia"
            "macos-tahoe"
          ];
        }
      ];
    };
  };
}
```

### Host-Conditional Provisioning in `.dotfiles`

If you manage your configuration from `/etc/nix-darwin/.dotfiles` or have multiple machines, you can selectively provision VMs depending on host properties (e.g., hostnames or disk constraints):

```nix
# /etc/nix-darwin/.dotfiles/hosts/workstation.nix
{ config, lib, pkgs, ... }:

{
  # Only provision Tahoe and Sequoia if on primary workstation
  nix-deboogey.tart.vms = lib.mkIf (config.networking.hostName == "workstation") [
    "macos-tahoe"
    "macos-sequoia"
  ];
}
```

---

## Declarative Tart Integration Layer (Defaults-On)

Every capability from the Tart ecosystem is configurable with sensible defaults enabled out of the box. See the full reference in [docs/integrations.md](file:///Users/8amps/nix-deboogey/docs/integrations.md).

### Highlights:
- **Shared Folders (VirtioFS)**: Automatically shares the host home directory (`enableHomeShare = true`) at `/Volumes/My Shared Files/home`. Additional folders can be added via `defaults.sharedFolders`.
- **Networking Modes**: Defaults to `"shared"` (Virtualization NAT). Supports `"bridged"` (`bridgedInterface = "en0"`), `"host-only"`, and `"softnet"` with port forwarding rules.
- **Orchard Orchestration**: Enabled by default in local dev mode (`orchard.mode = "dev"`), managed under `launchd.user.agents.orchard-dev`. Includes `orchard-ssh` and `orchard-vnc` aliases.
- **SSH Helpers**: Automatically provides `tart-ssh <vm>` and `tart-scp` shell functions using `sshpass` and dynamic IP discovery via `tart ip`.
- **CI Scaffolds**: Pre-configures Cirrus CLI and Packer (`cirrusCli = true`, `packer = true`). Generates templates for GitHub Actions, GitLab, and Buildkite when enabled.
- **Disk Sizing Guard**: Cloned VMs default to 50 GB (`defaults.diskSize = 50`) and are automatically and idempotently resized on activation.

```nix
nix-deboogey.tart = {
  enable = true;
  defaults = {
    cpu = 6;
    memory = 12;
    diskSize = 60;
    net = "shared";
    enableHomeShare = true;
  };
  vms = [
    "macos-sequoia"
    {
      name = "macos-tahoe";
      cpu = 8;
      memory = 16;
      autoStart = false;
    }
  ];
};
```

---

## Building Locally with HashiCorp Packer

Ensure you have HashiCorp Packer and the Tart CLI installed:

```bash
brew install cirruslabs/cli/tart hashicorp/tap/packer
```

### 1. Initialize Packer Tart Plugin

```bash
packer init packer/templates/macos-tahoe-deboogey.pkr.hcl
```

### 2. Build Target VM

```bash
# Build Tahoe (macOS >= 26)
packer build -var "pre_26=false" packer/templates/macos-tahoe-deboogey.pkr.hcl

# Build Sequoia (macOS < 26)
packer build -var "pre_26=true" packer/templates/macos-sequoia-deboogey.pkr.hcl
```

During build, the `scripts/provisioners/check-version-gate.sh` script executes `sw_vers -productVersion` inside the VM and aborts immediately if the running version does not align with the expected tweak loader.

### 3. Push Image to GHCR

```bash
echo "$GITHUB_TOKEN" | tart login ghcr.io -u "$GH_USER" --password-stdin
tart push macos-tahoe-deboogey ghcr.io/aspauldingcode/nix-deboogey/macos-tahoe-deboogey:latest
```

---

## GitHub Actions CI/CD

The workflow `.github/workflows/build-tart-vms.yml` automates builds on Apple Silicon runners (`macos-14`/`macos-15`):
- Runs weekly on cron (`0 0 * * 0`).
- Runs on pushes touching `packer/**`, `scripts/**`, or workflow files.
- Provides manual dispatch via `workflow_dispatch` with target version filtering and `pre_26` override support.
- Pushes both `:latest` and date-stamped tags (`:YYYYMMDD`) to GHCR.

---

## Repository Structure

```
aspauldingcode/nix-deboogey/
├── flake.nix                               # Flake outputs: darwinModules & ephemeral apps
├── modules/
│   └── default.nix                         # nix-darwin module for declarative VM provisioning
├── apps/
│   └── ephemeral.nix                       # Ephemeral runner app generator
├── packer/templates/
│   ├── macos-golden-gate-deboogey.pkr.hcl  # Golden Gate template
│   ├── macos-tahoe-deboogey.pkr.hcl        # Tahoe template (macOS 26)
│   ├── macos-sequoia-deboogey.pkr.hcl      # Sequoia template (macOS 15)
│   ├── macos-sonoma-deboogey.pkr.hcl       # Sonoma template (macOS 14)
│   ├── macos-ventura-deboogey.pkr.hcl      # Ventura template (macOS 13)
│   └── macos-monterey-deboogey.pkr.hcl     # Monterey template (macOS 12)
├── scripts/provisioners/
│   ├── check-version-gate.sh               # sw_vers gatekeeper to ensure loader reproducibility
│   ├── install-deboogey.sh                 # Shared Deboogey + Xcode CLT provisioner
│   ├── install-ammonia.sh                  # Ammonia provisioner for macOS < 26
│   └── install-plugin-playground.sh        # Plugin Playground provisioner for macOS >= 26
├── .github/workflows/
│   └── build-tart-vms.yml                  # GitHub Actions CI matrix build & publish pipeline
└── README.md                               # Project documentation & usage instructions
```

---

## License

This repository is licensed under the Apache 2.0 License. Tart CLI is subject to its respective Fair Source License.
