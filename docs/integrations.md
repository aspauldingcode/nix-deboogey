# Tart Integration Layer (Defaults-On)

The `nix-deboogey` module provides a declarative integration layer for macOS [Tart](https://tart.run/) virtual machines in `nix-darwin`. All capabilities and perks from the Cirrus Labs Tart ecosystem are **configurable and enabled by default**.

---

## Perk to Option Mapping Matrix

| Tart Perk | Nix Option Path | Type | Default Value | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Tart CLI Package** | `nix-deboogey.tart.package` | `package` | `pkgs.tart` *(nixpkgs)* | Tart CLI package derivation. |
| **Homebrew Fallback** | `nix-deboogey.tart.useHomebrewTart` | `bool` | `!(pkgs ? tart)` | Automatically falls back to `cirruslabs/cli/tart` via Homebrew when missing from nixpkgs. |
| **Global Activation** | `nix-deboogey.tart.enable` | `bool` | `true` | Enables Tart management, default VM templates, Orchard, and tools even if `vms = []`. |
| **Auto Image Pull** | `nix-deboogey.tart.autoPull` | `bool` | `true` | Automatically checks and pulls latest OCI images on system activation. |
| **VirtioFS Shared Folders** | `nix-deboogey.tart.defaults.sharedFolders` | `listOf submodule` | `[]` | List of host folders shared with guest via `--dir=<name>:<path>[:ro]`. |
| **Host Home Sharing** | `nix-deboogey.tart.defaults.enableHomeShare` | `bool` | `true` | Automatically mounts host user home directory at `/Volumes/My Shared Files/home`. |
| **Networking Mode** | `nix-deboogey.tart.defaults.net` | `enum [ "shared" "bridged" "host-only" "softnet" ]` | `"shared"` | Network isolation mode (default is shared NAT). |
| **Bridged Interface** | `nix-deboogey.tart.defaults.bridgedInterface` | `string` | `"en0"` | Physical network interface used when `net = "bridged"`. |
| **Softnet Port Forwarding** | `nix-deboogey.tart.defaults.softnetPorts` | `listOf string` | `[]` | Port forwarding rules when `net = "softnet"`. |
| **Softnet CIDR Filters** | `nix-deboogey.tart.defaults.softnetAllow` / `.softnetBlock` | `listOf string` | `[]` | IP allow/deny rules when running in Softnet mode. |
| **Orchard VM Orchestration**| `nix-deboogey.orchard.enable` | `bool` | `true` | Declaratively manages Orchard virtualization cluster/orchestration daemon. |
| **Orchard Mode** | `nix-deboogey.orchard.mode` | `enum [ "dev" "controller" "worker" "none" ]` | `"dev"` | Runs `orchard dev` locally under launchd user agent with `RunAtLoad = true`. |
| **Orchard Controller URL** | `nix-deboogey.orchard.controllerUrl` | `nullOr string` | `null` | Required for worker nodes joining a centralized Orchard cluster. |
| **Orchard License Tier** | `nix-deboogey.orchard.licenseTier` | `enum [ "free" "gold" "platinum" ]` | `"free"` | Sets `ORCHARD_LICENSE_TIER` environment variable for launchd agent. |
| **Orchard Shell Aliases** | `environment.shellAliases` | `attrs` | `orchard-ssh`, `orchard-vnc` | Quick CLI commands for jumping into managed VMs. |
| **SSH Helpers (`tart-ssh`)** | `nix-deboogey.tart.defaults.ssh.enable` | `bool` | `true` | Injects non-interactive `tart-ssh <vm>` and `tart-scp` shell functions using `sshpass`. |
| **Default Guest Credentials**| `nix-deboogey.tart.defaults.ssh.user` / `.password` | `string` | `"admin"` / `"admin"` | Credentials matching Cirrus Labs vanilla image defaults. |
| **Orchard SSH Jump-Host** | `~/.ssh/config` `ProxyJump` | `string` | Auto-configured | Automatically configures SSH jump host for `*.orchard` hosts. |
| **Cirrus CLI** | `nix-deboogey.integrations.cirrusCli` | `bool` | `true` | Installs `cirruslabs/cli/cirrus` via Homebrew for running containerized Tart tasks. |
| **HashiCorp Packer** | `nix-deboogey.integrations.packer` | `bool` | `true` | Installs HashiCorp Packer via Homebrew for VM image authoring. |
| **GitHub Actions Scaffold** | `nix-deboogey.integrations.githubActions`| `bool` | `false` | Generates self-hosted Tart workflow scaffold into `~/tart-integrations/github-actions/`. |
| **GitLab Runner Scaffold** | `nix-deboogey.integrations.gitlabRunner` | `bool` | `false` | Generates custom executor configuration for GitLab runner into `~/tart-integrations/gitlab/`. |
| **Buildkite Scaffold** | `nix-deboogey.integrations.buildkite` | `bool` | `false` | Generates Buildkite pipeline step scaffold into `~/tart-integrations/buildkite/`. |
| **Guest Agent Integration** | `nix-deboogey.tart.defaults.guestAgent` | `bool` | `true` | Enables dynamic IP resolution (`tart ip`), clipboard sharing, and `tart exec`. |
| **Headless vs. GUI Mode** | `nix-deboogey.tart.defaults.headless` | `bool` | `false` *(persistent)* / `true` *(ephemeral)* | Persistent VMs launch with GUI available; ephemeral apps default to `--no-graphics`. |
| **Disk Sizing & Resize** | `nix-deboogey.tart.defaults.diskSize` | `int` (GB) | `50` | Automatically resizes cloned VM disk if below target size using `tart set --disk-size`. |
| **CPU Allocation** | `nix-deboogey.tart.defaults.cpu` | `int` | `4` | Number of virtual cores assigned to the VM. |
| **RAM Allocation** | `nix-deboogey.tart.defaults.memory` | `int` (GB) | `8` | Amount of memory assigned to the VM (passed as MB to Tart). |
| **Auto-Start Service** | `nix-deboogey.tart.defaults.autoStart` | `bool` | `false` | When true, starts the persistent VM at user login via `launchd.user.agents.tart-<vm>`. |

---

## Detailed Feature Explanations

### 1. VirtioFS Shared Folders
Every VM inherits the `defaults.sharedFolders` list plus a home directory share (when `enableHomeShare = true`).
- In macOS guests, folders are mounted at:
  ```
  /Volumes/My Shared Files/<share-name>
  ```
- In Linux guests (if used):
  ```bash
  mount -t virtiofs <share-name> /mnt/<share-name>
  ```

### 2. Networking Modes
Configure the networking mode either globally in `defaults.net` or per-VM:
- `"shared"`: Virtualization.framework NAT (default).
- `"bridged"`: Bridges to physical interface specified in `bridgedInterface` (default `"en0"`).
- `"host-only"`: Completely isolated from the internet and external LAN; accessible only from the host.
- `"softnet"`: Software-defined networking with optional port forwarding rules (`softnetPorts = [ "8080:80" ]`).

### 3. Orchard Local Cluster (`orchard dev`)
Enabled by default in `"dev"` mode:
- Installs `pkgs.orchard` (nixpkgs).
- Launches `orchard dev` via `launchd.user.agents.orchard-dev` with `KeepAlive = true` and `RunAtLoad = true`.
- To completely remove Orchard, set:
  ```nix
  nix-deboogey.orchard.mode = "none";
  ```

### 4. SSH Helper Functions
The module configures shell functions directly in your interactive environment:
```bash
# Connect directly to VM via SSH using automatic IP lookup and default credentials
tart-ssh macos-sequoia-deboogey

# Copy files using scp
tart-scp ./myfile admin@$(tart ip macos-sequoia-deboogey):/Users/admin/
```

### 5. Idempotent Disk Sizing Guard
When provisioning VMs, the activation script inspects the current disk allocation of the cloned image:
- If the VM's current disk is smaller than `diskSize` (default 50 GB), it runs `tart set <vm> --disk-size <size>`.
- If already at or above `diskSize`, no modification is made, guaranteeing zero build disruption.

---

## Example nix-darwin Configuration

```nix
{ config, pkgs, ... }:

{
  nix-deboogey.tart = {
    enable = true;

    # Global defaults across all VMs
    defaults = {
      cpu = 6;
      memory = 12;
      diskSize = 60;
      net = "shared";
      enableHomeShare = true;

      sharedFolders = [
        {
          name = "work";
          path = "/Users/admin/Workspace";
          ro = false;
        }
      ];
    };

    # List of VMs to provision
    vms = [
      # String coerced to default submodule
      "macos-sequoia"

      # Explicit override
      {
        name = "macos-tahoe";
        cpu = 8;
        memory = 16;
        net = "softnet";
        softnetPorts = [ "8080:80" ];
        autoStart = false;
      }
    ];
  };

  # Orchard local cluster configuration
  nix-deboogey.orchard = {
    enable = true;
    mode = "dev";
  };

  # CI Tooling
  nix-deboogey.integrations = {
    cirrusCli = true;
    packer = true;
    githubActions = true;
  };
}
```
