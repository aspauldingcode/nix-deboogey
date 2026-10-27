packer {
  required_plugins {
    tart = {
      version = ">= 1.13.0"
      source  = "github.com/cirruslabs/tart"
    }
  }
}

variable "version" {
  type        = string
  description = "macOS codename: golden-gate, tahoe, sequoia, sonoma, ventura, monterey"
}

variable "pre_26" {
  type        = bool
  default     = false
  description = "true = macOS < 26 (Ammonia), false = macOS >= 26 (Plugin Playground)"
}

variable "plugin_playground_pkg_url" {
  type    = string
  default = ""
}

source "tart-cli" "tart" {
  vm_base_name = "ghcr.io/cirruslabs/macos-${var.version}-vanilla:latest"
  vm_name      = "macos-${var.version}-deboogey"
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

  provisioner "shell" {
    environment_vars = [
      "EXPECTED_PRE_26=${var.pre_26}",
      "MACOS_CODENAME=${var.version}"
    ]
    script = "${path.root}/../scripts/provisioners/check-version-gate.sh"
  }

  provisioner "shell" {
    script = "${path.root}/../scripts/provisioners/disable-sip.sh"
  }

  provisioner "shell" {
    script = "${path.root}/../scripts/provisioners/install-deboogey.sh"
  }

  provisioner "shell" {
    environment_vars = ["PLUGIN_PLAYGROUND_PKG_URL=${var.plugin_playground_pkg_url}"]
    script = var.pre_26 ? "${path.root}/../scripts/provisioners/install-ammonia.sh" : "${path.root}/../scripts/provisioners/install-plugin-playground.sh"
  }

  provisioner "shell" {
    inline = ["sync"]
  }
}
