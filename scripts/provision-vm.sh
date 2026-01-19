#!/bin/bash
# provision-vm.sh - Minimal provisioning for Deboogey VMs
set -euo pipefail

echo "=== Step 1: Installing Nix ==="
curl -fsSL https://install.determinate.systems/determinate-pkg/stable/Universal -o /tmp/nix.pkg
sudo installer -pkg /tmp/nix.pkg -target /
rm /tmp/nix.pkg

echo "=== Step 2: Installing Ammonia ==="
curl -fsSL https://github.com/CoreBedtime/ammonia/releases/download/1.5/ammonia.pkg -o /tmp/ammonia.pkg
sudo installer -pkg /tmp/ammonia.pkg -target /
rm /tmp/ammonia.pkg

echo "=== Step 3: Installing Deboogey ==="
curl -fsSL https://github.com/theoderoy/Deboogey/releases/download/rel-1.1/Deboogey.aar -o /tmp/Deboogey.aar
mkdir -p /tmp/extract
aa extract -v -i /tmp/Deboogey.aar -d /tmp/extract
sudo mv /tmp/extract/Deboogey.app /Applications/
rm -rf /tmp/Deboogey.aar /tmp/extract

echo "=== Step 4: Creating Guest Flake ==="
mkdir -p "$HOME/Desktop/nix-deboogey"
cat > "$HOME/Desktop/nix-deboogey/flake.nix" << 'EOF'
{
  description = "Deboogey guest flake";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  outputs = { self, nixpkgs }: {
    packages.aarch64-darwin.default = nixpkgs.legacyPackages.aarch64-darwin.writeShellScriptBin "deboogey" "open /Applications/Deboogey.app";
    apps.aarch64-darwin.default = { type = "app"; program = "${self.packages.aarch64-darwin.default}/bin/deboogey"; };
  };
}
EOF

echo "=== Provisioning Complete ==="
