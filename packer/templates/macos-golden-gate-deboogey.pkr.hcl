packer {
  required_plugins {
    tart = {
      version = ">= 1.13.0"
      source  = "github.com/cirruslabs/tart"
    }
  }
}

variable "pre_26" {
  type        = bool
  default     = false
  description = "Whether macOS version is < 26. Defaults to false (>= 26: Plugin Playground)."
}

variable "plugin_playground_pkg_url" {
  type        = string
  default     = ""
  description = "Optional pre-built Plugin Playground pkg URL to bypass in-VM compilation."
}

locals {
  macos_version = "golden-gate"
  is_pre_26     = var.pre_26
}

source "tart-cli" "tart" {
  vm_base_name = "ghcr.io/cirruslabs/macos-${local.macos_version}-vanilla:latest"
  vm_name      = "macos-${local.macos_version}-deboogey"
  cpu_count    = 4
  memory_gb    = 8
  disk_size_gb = 50
  ssh_username = "admin"
  ssh_password = "admin"
  ssh_timeout  = "120s"
  headless     = true
}

build {
  sources = ["source.tart-cli.tart"]

  # Step 1: Validate version gate to prevent silent drift
  provisioner "shell" {
    environment_vars = [
      "EXPECTED_PRE_26=${local.is_pre_26 ? "true" : "false"}",
      "MACOS_CODENAME=${local.macos_version}"
    ]
    script = "${path.root}/../../scripts/provisioners/check-version-gate.sh"
  }

  # Step 2: Shared Deboogey + Xcode CLT installation
  provisioner "shell" {
    script = "${path.root}/../../scripts/provisioners/install-deboogey.sh"
  }

  # Step 3: Version-gated tweak loader (Ammonia if < 26, Plugin Playground if >= 26)
  provisioner "shell" {
    environment_vars = [
      "PLUGIN_PLAYGROUND_PKG_URL=${var.plugin_playground_pkg_url}"
    ]
    script = local.is_pre_26 ? "${path.root}/../../scripts/provisioners/install-ammonia.sh" : "${path.root}/../../scripts/provisioners/install-plugin-playground.sh"
  }

  # Step 4: Final sync
  provisioner "shell" {
    inline = [
      "echo '==> Provisioning complete. Syncing filesystem...'",
      "sync"
    ]
  }
}
