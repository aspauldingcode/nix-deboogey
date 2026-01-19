# Function to create Tart wrapper scripts for a specific VM
{ pkgs, vmConfig }:

let
  # Helper to create a script package
  makeScript = name: script: pkgs.writeShellScriptBin name script;
  
  vmName = vmConfig.vmName;
  image = vmConfig.image;
  
in {
  # Clone VM from registry
  clone = makeScript "clone-${vmName}" ''
    set -euo pipefail
    echo "Cloning ${vmConfig.description}..."
    echo "Image: ${image}"
    echo "VM Name: ${vmName}"
    ${pkgs.tart}/bin/tart clone "${image}" "${vmName}" "$@"
    echo "Clone complete! Run with: nix run .#run-${builtins.substring 9 100 vmName}"
  '';
  
  # Run VM with optional directory sharing
  run = makeScript "run-${vmName}" ''
    set -euo pipefail
    echo "Starting ${vmName}..."
    ${pkgs.tart}/bin/tart run "${vmName}" "$@"
  '';
  
  # Run VM headless (no graphics)
  run-headless = makeScript "run-headless-${vmName}" ''
    set -euo pipefail
    echo "Starting ${vmName} in headless mode..."
    ${pkgs.tart}/bin/tart run "${vmName}" --no-graphics "$@"
  '';
  
  # Get VM IP address
  ip = makeScript "ip-${vmName}" ''
    set -euo pipefail
    ${pkgs.tart}/bin/tart ip "${vmName}" "$@"
  '';
  
  # Execute command in VM (requires tart-guest-agent)
  exec = makeScript "exec-${vmName}" ''
    set -euo pipefail
    ${pkgs.tart}/bin/tart exec "${vmName}" "$@"
  '';
  
  # Stop VM
  stop = makeScript "stop-${vmName}" ''
    set -euo pipefail
    echo "Stopping ${vmName}..."
    ${pkgs.tart}/bin/tart stop "${vmName}" "$@"
    echo "VM stopped."
  '';
  
  # Delete VM
  delete = makeScript "delete-${vmName}" ''
    set -euo pipefail
    echo "Deleting ${vmName}..."
    ${pkgs.tart}/bin/tart delete "${vmName}" "$@"
    echo "VM deleted."
  '';
  
  # Suspend VM
  suspend = makeScript "suspend-${vmName}" ''
    set -euo pipefail
    echo "Suspending ${vmName}..."
    ${pkgs.tart}/bin/tart suspend "${vmName}" "$@"
    echo "VM suspended."
  '';
  
  # Get VM configuration
  get = makeScript "get-${vmName}" ''
    set -euo pipefail
    ${pkgs.tart}/bin/tart get "${vmName}" "$@"
  '';
  
  # Set VM configuration
  set = makeScript "set-${vmName}" ''
    set -euo pipefail
    ${pkgs.tart}/bin/tart set "${vmName}" "$@"
  '';
  
  # Export VM to file
  export = makeScript "export-${vmName}" ''
    set -euo pipefail
    echo "Exporting ${vmName}..."
    ${pkgs.tart}/bin/tart export "${vmName}" "$@"
  '';
  
  # SSH into VM
  ssh = makeScript "ssh-${vmName}" ''
    set -euo pipefail
    VM_IP=$(${pkgs.tart}/bin/tart ip "${vmName}" --wait 60 2>/dev/null || true)
    if [ -z "$VM_IP" ]; then
      echo "Error: Could not get IP for ${vmName}. Is the VM running?"
      exit 1
    fi
    echo "Connecting to ${vmName} at $VM_IP..."
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "admin@$VM_IP" "$@"
  '';
  
  # Provision Deboogey in VM
  provision = makeScript "provision-${vmName}" ''
    set -euo pipefail
    echo "Provisioning Deboogey in ${vmName}..."
    
    # Get VM IP
    VM_IP=$(${pkgs.tart}/bin/tart ip "${vmName}" --wait 60 2>/dev/null || true)
    if [ -z "$VM_IP" ]; then
      echo "Error: Could not get IP for ${vmName}. Is the VM running?"
      exit 1
    fi
    
    echo "VM IP: $VM_IP"
    echo "Installing Deboogey..."
    
    # Use tart exec if available, otherwise SSH
    ${pkgs.tart}/bin/tart exec "${vmName}" bash -c '
      set -e
      cd ~
      if [ ! -d "Deboogey" ]; then
        git clone https://github.com/theoderoy/Deboogey.git
      else
        cd Deboogey && git pull && cd ..
      fi
      cd Deboogey
      xcodebuild -project Deboogey.xcodeproj -scheme Deboogey -configuration Release -derivedDataPath build
      cp -r build/Build/Products/Release/Deboogey.app /Applications/
      echo "Deboogey installed to /Applications/Deboogey.app"
    ' || {
      echo "tart exec failed, trying SSH..."
      ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "admin@$VM_IP" '
        set -e
        cd ~
        if [ ! -d "Deboogey" ]; then
          git clone https://github.com/theoderoy/Deboogey.git
        else
          cd Deboogey && git pull && cd ..
        fi
        cd Deboogey
        xcodebuild -project Deboogey.xcodeproj -scheme Deboogey -configuration Release -derivedDataPath build
        cp -r build/Build/Products/Release/Deboogey.app /Applications/
        echo "Deboogey installed to /Applications/Deboogey.app"
      '
    }
    
    echo "Provisioning complete!"
  '';
}
