{
  description = "Nix flake providing Deboogey in macOS Tart VMs for ARM-based Macs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;  # Tart has fairsource09 license
        };
      };
      
      # Import VM configurations
      vmConfigs = import ./nix/vm-configs.nix;
      
      # Import wrapper factory
      makeTartWrapper = vmConfig: import ./nix/make-tart-wrapper.nix { inherit pkgs vmConfig; };
      
      # Generate wrappers for each VM
      tahoeWrappers = makeTartWrapper vmConfigs.tahoe;
      sequoiaWrappers = makeTartWrapper vmConfigs.sequoia;
      sonomaWrappers = makeTartWrapper vmConfigs.sonoma;
      venturaWrappers = makeTartWrapper vmConfigs.ventura;
      montereyWrappers = makeTartWrapper vmConfigs.monterey;
      
      # Script paths
      scriptsDir = ./scripts;
      tartBin = "${pkgs.tart}/bin/tart";
      lolcatBin = "${pkgs.lolcat}/bin/lolcat";
      figletBin = "${pkgs.figlet}/bin/figlet";
      
      # ========================================
      # Prebuilt creation commands
      # ========================================
      makePrebuiltCreator = version: let
        baseImages = {
          tahoe = "ghcr.io/cirruslabs/macos-tahoe-xcode:latest";
          sequoia = "ghcr.io/cirruslabs/macos-sequoia-xcode:latest";
          sonoma = "ghcr.io/cirruslabs/macos-sonoma-xcode:latest";
          ventura = "ghcr.io/cirruslabs/macos-ventura-xcode:latest";
          monterey = "ghcr.io/cirruslabs/macos-monterey-xcode:latest";
        };
        targetImages = {
          tahoe = "ghcr.io/aspauldingcode/deboogey-tahoe:latest";
          sequoia = "ghcr.io/aspauldingcode/deboogey-sequoia:latest";
          sonoma = "ghcr.io/aspauldingcode/deboogey-sonoma:latest";
          ventura = "ghcr.io/aspauldingcode/deboogey-ventura:latest";
          monterey = "ghcr.io/aspauldingcode/deboogey-monterey:latest";
        };
        baseImage = baseImages.${version};
        targetImage = targetImages.${version};
        vmName = "deboogey-${version}";
        buildVmName = "${vmName}-build";
      in pkgs.writeShellScriptBin "create-prebuilt-${version}" ''
        set -euo pipefail
        
        # Enforce nix develop context
        if [ -z "''${DEBOOGEY_DEV:-}" ]; then
          echo "❌ ERROR: This command must be run within a 'nix develop' shell."
          echo "Please run 'nix develop' first, then try again."
          exit 1
        fi

        # Enforce credentials
        if [ -z "''${GH_USER:-}" ] || [ -z "''${GITHUB_TOKEN:-}" ]; then
          echo "❌ ERROR: GH_USER or GITHUB_TOKEN not set."
          echo "These are required for automatic pushing to the registry."
          echo "They should have been set up automatically by 'nix develop'."
          exit 1
        fi
        
        banner() {
          ${figletBin} "$1" | ${lolcatBin} -f
        }
        
        info() {
          echo "$1"
        }
        
        # Cleanup trap to ensure background VM is killed on exit
        VM_PID=""
        cleanup() {
          if [ -n "$VM_PID" ]; then
            echo "Cleaning up VM process (PID: $VM_PID)..."
            kill $VM_PID 2>/dev/null || true
          fi
        }
        trap cleanup EXIT
        
        DO_PUSH="true"
        while [[ $# -gt 0 ]]; do
          case $1 in
            --no-push)
              DO_PUSH="false"
              shift
              ;;
            *)
              shift
              ;;
          esac
        done
        
        # Step 0: Login to GHCR
        banner "Auth"
        info "Logging in to ghcr.io as $GH_USER..."
        echo "$GITHUB_TOKEN" | ${tartBin} login ghcr.io --username "$GH_USER" --password-stdin
        echo ""
        
        banner "${version}"
        info "Base image: ${baseImage}"
        info "Target image: ${targetImage}"
        info "Build VM name: ${buildVmName}"
        echo ""
        
        # Step 1: Clone from base
        banner "Step 1"
        info "Cloning base image..."
        if ${tartBin} list --quiet | grep -q "^${buildVmName}$"; then
          info "Deleting existing build VM..."
          ${tartBin} delete "${buildVmName}" || true
        fi
        ${tartBin} clone "${baseImage}" "${buildVmName}"
        info "Clone complete."
        
        # Step 1.5: Clean up VMs to avoid system limit
        echo ""
        banner "Cleanup"
        info "Cleaning up VMs to avoid system limit..."
        
        # Aggressively kill any existing tart run processes that might be holding slots
        EXISTING_TART_PIDS=$(pgrep -f "tart run" || true)
        if [ -n "$EXISTING_TART_PIDS" ]; then
          info "Found existing tart run processes, killing them to free up slots..."
          echo "$EXISTING_TART_PIDS" | while read pid; do
            info "  Killing PID $pid..."
            kill -9 "$pid" 2>/dev/null || true
          done
        fi

        # Stop all running VMs first (as reported by tart list)
        RUNNING_VMS=$(${tartBin} list | awk 'NR>1 && $NF=="running" {print $2}')
        if [ -n "$RUNNING_VMS" ]; then
          info "Stopping running VMs..."
          echo "$RUNNING_VMS" | while read vm; do
            info "  Stopping $vm..."
            ${tartBin} stop "$vm" 2>/dev/null || true
          done
        fi
        
        # Delete OCI cache VMs (they can be re-pulled)
        info "Deleting OCI cache VMs to free up space..."
        OCI_VMS=$(${tartBin} list | awk 'NR>1 && $1=="OCI" {print $2}')
        if [ -n "$OCI_VMS" ]; then
          echo "$OCI_VMS" | while read vm; do
            info "  Deleting $vm..."
            ${tartBin} delete "$vm" 2>/dev/null || true
          done
          info "OCI cache VMs deleted."
        fi
        
        # Prune unused images
        info "Pruning unused images..."
        ${tartBin} prune 2>/dev/null || true
        
        info "Cleanup complete."
        
        # Step 2: Start VM headless
        echo ""
        banner "Step 2"
        info "Starting VM for provisioning..."
        info "Starting ${buildVmName} in headless mode..."
        ${tartBin} run "${buildVmName}" --no-graphics &
        VM_PID=$!
        info "VM started (PID: $VM_PID)"
        
        # Wait for VM to boot and get IP
        info "Waiting for VM to boot..."
        sleep 30
        
        VM_IP=""
        for i in {1..60}; do
          VM_IP=$(${tartBin} ip "${buildVmName}" 2>/dev/null || true)
          if [ -n "$VM_IP" ]; then
            info "VM IP: $VM_IP"
            break
          fi
          info "Waiting for IP... ($i/60)"
          sleep 5
        done
        
        if [ -z "$VM_IP" ]; then
          info "Error: Could not get VM IP after 5 minutes"
          kill $VM_PID 2>/dev/null || true
          exit 1
        fi
        
        # Step 3: Provision VM
        echo ""
        banner "Step 3"
        info "Provisioning VM (automated password)..."
        DISPLAY=:0 SSH_ASKPASS="${pkgs.writeShellScript "askpass" "echo admin"}" SSH_ASKPASS_REQUIRE=force scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${scriptsDir}/provision-vm.sh" "admin@$VM_IP:/tmp/provision-vm.sh"
        info "Running provisioning script..."
        DISPLAY=:0 SSH_ASKPASS="${pkgs.writeShellScript "askpass" "echo admin"}" SSH_ASKPASS_REQUIRE=force ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "admin@$VM_IP" "chmod +x /tmp/provision-vm.sh && /tmp/provision-vm.sh"
        info "Provisioning complete."
        
        # Step 4: Stop VM
        echo ""
        banner "Step 4"
        info "Stopping VM..."
        DISPLAY=:0 SSH_ASKPASS="${pkgs.writeShellScript "askpass" "echo admin"}" SSH_ASKPASS_REQUIRE=force ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            "admin@$VM_IP" "sudo shutdown -h now" 2>/dev/null || true
        
        sleep 10
        ${tartBin} stop "${buildVmName}" 2>/dev/null || true
        kill $VM_PID 2>/dev/null || true
        
        info "VM stopped."
        
        # Step 5: Rename to final name
        echo ""
        banner "Step 5"
        info "Renaming VM..."
        if ${tartBin} list --quiet | grep -q "^${vmName}$"; then
          info "Deleting existing ${vmName}..."
          ${tartBin} delete "${vmName}" || true
        fi
        ${tartBin} rename "${buildVmName}" "${vmName}"
        info "Renamed to ${vmName}"
        
        # Step 6: Push to GHCR
        if [ "$DO_PUSH" = "true" ]; then
          echo ""
          banner "Pushing"
          info "Pushing ${vmName} to ${targetImage}..."
          ${tartBin} push "${vmName}" "${targetImage}"
          info "Push complete!"
          echo ""
          info "Success! Prebuilt VM available at:"
          echo "  ${targetImage}"
        else
          echo ""
          info "Build complete. skipping push to GHCR."
          info "To push manually, run:"
          info "  nix run .#tart-push -- ${vmName} ${targetImage}"
        fi
        
        echo ""
        banner "Done"
      '';
      
      # ========================================
      # Generic Tart commands (not tied to specific VM)
      # ========================================
      genericCommands = {
        # List all VMs
        list = pkgs.writeShellScriptBin "tart-list" ''
          ${tartBin} list "$@"
        '';
        
        # Prune caches
        prune = pkgs.writeShellScriptBin "tart-prune" ''
          ${tartBin} prune "$@"
        '';
        
        # Login to GHCR
        login-ghcr = pkgs.writeShellScriptBin "login-ghcr" ''
          set -euo pipefail
          info() {
            echo "$1"
          }
          if [ -z "''${GH_USER:-}" ] || [ -z "''${GITHUB_TOKEN:-}" ]; then
            info "Error: GH_USER or GITHUB_TOKEN not set"
            info "Set them in your .envrc (e.g. export GH_USER=username)"
            exit 1
          fi
          echo "$GITHUB_TOKEN" | ${tartBin} login ghcr.io --username "$GH_USER" --password-stdin
          info "Logged in to ghcr.io as $GH_USER"
        '';
        
        # Login to any registry
        login = pkgs.writeShellScriptBin "tart-login" ''
          ${tartBin} login "$@"
        '';
        
        # Logout from registry
        logout = pkgs.writeShellScriptBin "tart-logout" ''
          ${tartBin} logout "$@"
        '';
        
        # Pull remote VM
        pull = pkgs.writeShellScriptBin "tart-pull" ''
          ${tartBin} pull "$@"
        '';
        
        # Push VM to registry
        push = pkgs.writeShellScriptBin "tart-push" ''
          ${tartBin} push "$@"
        '';
        
        # Import VM from file
        import = pkgs.writeShellScriptBin "tart-import" ''
          ${tartBin} import "$@"
        '';
        
        # Create new VM
        create = pkgs.writeShellScriptBin "tart-create" ''
          ${tartBin} create "$@"
        '';
        
        # Rename VM
        rename = pkgs.writeShellScriptBin "tart-rename" ''
          ${tartBin} rename "$@"
        '';
        
        # Generic run (specify VM name)
        run = pkgs.writeShellScriptBin "tart-run" ''
          ${tartBin} run "$@"
        '';
        
        # Generic clone (specify source and name)
        clone = pkgs.writeShellScriptBin "tart-clone" ''
          ${tartBin} clone "$@"
        '';
        
        # Generic stop
        stop = pkgs.writeShellScriptBin "tart-stop" ''
          ${tartBin} stop "$@"
        '';
        
        # Generic delete
        delete = pkgs.writeShellScriptBin "tart-delete" ''
          ${tartBin} delete "$@"
        '';
        
        # Generic exec
        exec = pkgs.writeShellScriptBin "tart-exec" ''
          ${tartBin} exec "$@"
        '';
        
        # Generic IP
        ip = pkgs.writeShellScriptBin "tart-ip" ''
          ${tartBin} ip "$@"
        '';
        
        # Generic get config
        get = pkgs.writeShellScriptBin "tart-get" ''
          ${tartBin} get "$@"
        '';
        
        # Generic set config
        set = pkgs.writeShellScriptBin "tart-set" ''
          ${tartBin} set "$@"
        '';
        
        # Generic suspend
        suspend = pkgs.writeShellScriptBin "tart-suspend" ''
          ${tartBin} suspend "$@"
        '';
        
        # Generic export
        export = pkgs.writeShellScriptBin "tart-export" ''
          ${tartBin} export "$@"
        '';
      };
      
      # SSH setup script
      setupSsh = pkgs.writeShellScriptBin "setup-ssh" ''
        set -euo pipefail
        
        info() {
          echo "$1"
        }
        
        VM_NAME="''${1:-}"
        if [ -z "$VM_NAME" ]; then
          info "Usage: setup-ssh <vm-name>"
          info "Example: setup-ssh deboogey-tahoe"
          exit 1
        fi
        
        SSH_KEY="$HOME/.ssh/tart_vm_key"
        SSH_CONFIG="$HOME/.ssh/config"
        
        # Generate SSH key if not exists
        if [ ! -f "$SSH_KEY" ]; then
          info "Generating SSH key pair..."
          ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -C "tart-vm-access"
          info "SSH key generated: $SSH_KEY"
        fi
        
        # Get VM IP
        info "Getting VM IP..."
        VM_IP=$(${tartBin} ip "$VM_NAME" --wait 60 2>/dev/null || true)
        if [ -z "$VM_IP" ]; then
          info "Error: Could not get IP for $VM_NAME. Is the VM running?"
          exit 1
        fi
        info "VM IP: $VM_IP"
        
        # Copy public key to VM
        info "Copying public key to VM (you may be prompted for the VM password)..."
        info "Default password for Cirrus Labs VMs is: admin"
        ssh-copy-id -i "$SSH_KEY.pub" -o StrictHostKeyChecking=no "admin@$VM_IP"
        
        # Add/update SSH config entry
        info "Updating SSH config..."
        if grep -q "Host $VM_NAME" "$SSH_CONFIG" 2>/dev/null; then
          info "SSH config entry for $VM_NAME already exists."
        else
          cat >> "$SSH_CONFIG" << EOF

Host $VM_NAME
    HostName $VM_IP
    User admin
    IdentityFile $SSH_KEY
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF
          info "SSH config entry added for $VM_NAME"
        fi
        
        echo ""
        info "SSH setup complete! You can now connect with:"
        info "  ssh $VM_NAME"
      '';
      
      # SFTP helper
      sftpHelper = pkgs.writeShellScriptBin "sftp-vm" ''
        set -euo pipefail
        info() {
          echo "$1"
        }
        
        VM_NAME="''${1:-}"
        if [ -z "$VM_NAME" ]; then
          info "Usage: sftp-vm <vm-name>"
          info "Example: sftp-vm deboogey-tahoe"
          exit 1
        fi
        
        VM_IP=$(${tartBin} ip "$VM_NAME" --wait 30 2>/dev/null || true)
        if [ -z "$VM_IP" ]; then
          info "Error: Could not get IP for $VM_NAME. Is the VM running?"
          exit 1
        fi
        
        info "Connecting to $VM_NAME via SFTP..."
        sftp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "admin@$VM_IP"
      '';
      
      # ========================================
      # Unified consumer commands (all-in-one)
      # ========================================
      makeUnifiedRunner = version: let
        ghcrImage = "ghcr.io/aspauldingcode/deboogey-${version}:latest";
        vmName = "deboogey-${version}";
      in pkgs.writeShellScriptBin "${version}" ''
        set -euo pipefail
        
        banner() {
          ${figletBin} "$1" | ${lolcatBin} -f
        }
        info() {
          echo "$1"
        }
        
        VM_NAME="${vmName}"
        GHCR_IMAGE="${ghcrImage}"
        
        banner "${version}"
        info "🍎 Deboogey ${version} - All-in-One Runner"
        echo ""
        
        # Step 1: Smart clone - only pull if VM doesn't exist
        if ${tartBin} list --quiet | grep -q "^$VM_NAME$"; then
          info "✅ VM '$VM_NAME' already exists locally. Skipping pull."
        else
          info "📦 Cloning '$GHCR_IMAGE'..."
          ${tartBin} clone "$GHCR_IMAGE" "$VM_NAME"
          info "✅ Clone complete."
        fi
        echo ""
        
        # Step 2: Start VM with shared home directory
        info "🚀 Starting VM with shared folders (~/)"
        info "   Access shared files at: /Volumes/My Shared Files"
        echo ""
        ${tartBin} run "$VM_NAME" --dir=~ &
        VM_PID=$!
        
        # Step 3: Wait for VM to boot and get IP
        info "⏳ Waiting for VM to boot..."
        VM_IP=""
        for i in {1..60}; do
          VM_IP=$(${tartBin} ip "$VM_NAME" 2>/dev/null || true)
          if [ -n "$VM_IP" ]; then
            break
          fi
          sleep 2
        done
        
        if [ -z "$VM_IP" ]; then
          info "❌ Could not get VM IP. Check the VM window."
          wait $VM_PID
          exit 1
        fi
        
        echo ""
        info "✅ VM is ready!"
        info ""
        info "📋 Connection Info:"
        info "   VM Name: $VM_NAME"
        info "   IP:      $VM_IP"
        info "   User:    admin"
        info "   Pass:    admin"
        echo ""
        info "🔗 Quick Commands (run in another terminal):"
        info "   ssh admin@$VM_IP"
        info "   sftp admin@$VM_IP"
        echo ""
        info "📁 Shared Folder (inside VM):"
        info "   /Volumes/My Shared Files"
        echo ""
        info "Press Ctrl+C to stop the VM."
        
        wait $VM_PID
      '';
      
      # Create all prebuilts
      createAllPrebuilts = pkgs.writeShellScriptBin "create-prebuilt-all" ''
        set -euo pipefail
        info() {
          echo "$1"
        }
        banner() {
          ${figletBin} "$1" | ${lolcatBin} -f
        }

        PUSH_FLAG="''${1:-}"
        
        banner "All Build"
        info "Creating all prebuilts..."
        for version in tahoe sequoia sonoma ventura monterey; do
          echo ""
          ${scriptsDir}/create-prebuilt.sh "$version" $PUSH_FLAG
        done
        
        echo ""
        banner "Finished"
        info "All prebuilts created!"
      '';
      
    in {
      # ============================================
      # Packages - VM-specific Tart command wrappers
      # ============================================
      packages.${system} = {
        # ----- Prebuilt Creation Commands -----
        create-prebuilt-tahoe = makePrebuiltCreator "tahoe";
        create-prebuilt-sequoia = makePrebuiltCreator "sequoia";
        create-prebuilt-sonoma = makePrebuiltCreator "sonoma";
        create-prebuilt-ventura = makePrebuiltCreator "ventura";
        create-prebuilt-monterey = makePrebuiltCreator "monterey";
        create-prebuilt-all = createAllPrebuilts;
        
        # ----- Unified Consumer Commands (all-in-one) -----
        tahoe = makeUnifiedRunner "tahoe";
        sequoia = makeUnifiedRunner "sequoia";
        sonoma = makeUnifiedRunner "sonoma";
        ventura = makeUnifiedRunner "ventura";
        monterey = makeUnifiedRunner "monterey";
        
        # ----- Tahoe (macOS 26.0) -----
        clone-tahoe = tahoeWrappers.clone;
        run-tahoe = tahoeWrappers.run;
        run-headless-tahoe = tahoeWrappers.run-headless;
        ip-tahoe = tahoeWrappers.ip;
        exec-tahoe = tahoeWrappers.exec;
        stop-tahoe = tahoeWrappers.stop;
        delete-tahoe = tahoeWrappers.delete;
        suspend-tahoe = tahoeWrappers.suspend;
        get-tahoe = tahoeWrappers.get;
        set-tahoe = tahoeWrappers.set;
        export-tahoe = tahoeWrappers.export;
        ssh-tahoe = tahoeWrappers.ssh;
        provision-tahoe = tahoeWrappers.provision;
        
        # ----- Sequoia (macOS 15.0) -----
        clone-sequoia = sequoiaWrappers.clone;
        run-sequoia = sequoiaWrappers.run;
        run-headless-sequoia = sequoiaWrappers.run-headless;
        ip-sequoia = sequoiaWrappers.ip;
        exec-sequoia = sequoiaWrappers.exec;
        stop-sequoia = sequoiaWrappers.stop;
        delete-sequoia = sequoiaWrappers.delete;
        suspend-sequoia = sequoiaWrappers.suspend;
        get-sequoia = sequoiaWrappers.get;
        set-sequoia = sequoiaWrappers.set;
        export-sequoia = sequoiaWrappers.export;
        ssh-sequoia = sequoiaWrappers.ssh;
        provision-sequoia = sequoiaWrappers.provision;
        
        # ----- Sonoma (macOS 14.0) -----
        clone-sonoma = sonomaWrappers.clone;
        run-sonoma = sonomaWrappers.run;
        run-headless-sonoma = sonomaWrappers.run-headless;
        ip-sonoma = sonomaWrappers.ip;
        exec-sonoma = sonomaWrappers.exec;
        stop-sonoma = sonomaWrappers.stop;
        delete-sonoma = sonomaWrappers.delete;
        suspend-sonoma = sonomaWrappers.suspend;
        get-sonoma = sonomaWrappers.get;
        set-sonoma = sonomaWrappers.set;
        export-sonoma = sonomaWrappers.export;
        ssh-sonoma = sonomaWrappers.ssh;
        provision-sonoma = sonomaWrappers.provision;
        
        # ----- Ventura (macOS 13.0) -----
        clone-ventura = venturaWrappers.clone;
        run-ventura = venturaWrappers.run;
        run-headless-ventura = venturaWrappers.run-headless;
        ip-ventura = venturaWrappers.ip;
        exec-ventura = venturaWrappers.exec;
        stop-ventura = venturaWrappers.stop;
        delete-ventura = venturaWrappers.delete;
        suspend-ventura = venturaWrappers.suspend;
        get-ventura = venturaWrappers.get;
        set-ventura = venturaWrappers.set;
        export-ventura = venturaWrappers.export;
        ssh-ventura = venturaWrappers.ssh;
        provision-ventura = venturaWrappers.provision;
        
        # ----- Monterey (macOS 12.0) -----
        clone-monterey = montereyWrappers.clone;
        run-monterey = montereyWrappers.run;
        run-headless-monterey = montereyWrappers.run-headless;
        ip-monterey = montereyWrappers.ip;
        exec-monterey = montereyWrappers.exec;
        stop-monterey = montereyWrappers.stop;
        delete-monterey = montereyWrappers.delete;
        suspend-monterey = montereyWrappers.suspend;
        get-monterey = montereyWrappers.get;
        set-monterey = montereyWrappers.set;
        export-monterey = montereyWrappers.export;
        ssh-monterey = montereyWrappers.ssh;
        provision-monterey = montereyWrappers.provision;
        
        # ----- Generic Tart commands -----
        tart-list = genericCommands.list;
        tart-prune = genericCommands.prune;
        login-ghcr = genericCommands.login-ghcr;
        tart-login = genericCommands.login;
        tart-logout = genericCommands.logout;
        tart-pull = genericCommands.pull;
        tart-push = genericCommands.push;
        tart-import = genericCommands.import;
        tart-create = genericCommands.create;
        tart-rename = genericCommands.rename;
        tart-run = genericCommands.run;
        tart-clone = genericCommands.clone;
        tart-stop = genericCommands.stop;
        tart-delete = genericCommands.delete;
        tart-exec = genericCommands.exec;
        tart-ip = genericCommands.ip;
        tart-get = genericCommands.get;
        tart-set = genericCommands.set;
        tart-suspend = genericCommands.suspend;
        tart-export = genericCommands.export;
        
        # ----- Utility scripts -----
        setup-ssh = setupSsh;
        sftp-vm = sftpHelper;
        
        # Default package is clone-tahoe
        default = tahoeWrappers.clone;
      };
      
      # ============================================
      # Apps - convenient `nix run` aliases
      # ============================================
      apps.${system} = {
        # Default app clones the Tahoe VM
        default = {
          type = "app";
          program = "${tahoeWrappers.clone}/bin/clone-deboogey-tahoe";
        };
      };
      
      # ============================================
      # Development shell with all tools
      # ============================================
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          git
          clang
          tart
          openssh
          curl
          unzip
          figlet
          lolcat
          docker-client
          direnv
        ];
        
        shellHook = ''
          ${pkgs.figlet}/bin/figlet "Deboogey" | ${pkgs.lolcat}/bin/lolcat
          echo "🍎 nix-deboogey development environment"
          echo ""
          
          export DEBOOGEY_DEV=1

          # Automated .envrc management
          if [ -f .envrc ]; then
            echo "🔐 Sourcing .envrc..."
            set -a
            source .envrc
            set +a
          fi

          if [ -t 0 ]; then
            SETUP_NEEDED=0
            if [ -z "''${GH_USER:-}" ] || [ -z "''${GITHUB_TOKEN:-}" ]; then
                SETUP_NEEDED=1
            fi

            if [ "$SETUP_NEEDED" -eq 1 ]; then
              echo "⚠️  Environment credentials (GH_USER or GITHUB_TOKEN) are missing."
              echo "Would you like to set them now? (They will be saved to .envrc)"
              
              if [ -z "''${GH_USER:-}" ]; then
                printf "Enter your GitHub username: "
                read -r NEW_USER
              fi
              
              if [ -z "''${GITHUB_TOKEN:-}" ]; then
                echo "Get a Token (classic) at: https://github.com/settings/tokens"
                echo "Required scopes: repo, read:packages, write:packages"
                printf "Enter your ghp_ token: "
                read -r NEW_TOKEN
              fi

              if [ -n "''${NEW_USER:-}" ] || [ -n "''${NEW_TOKEN:-}" ]; then
                [ ! -f .envrc ] && echo "# nix-deboogey environment variables" > .envrc
                [ -n "''${NEW_USER:-}" ] && echo "export GH_USER=$NEW_USER" >> .envrc && export GH_USER=$NEW_USER
                if [ -n "''${NEW_TOKEN:-}" ]; then
                  echo "# Get token (classic) at: https://github.com/settings/tokens" >> .envrc
                  echo "# Required scopes: repo, read:packages, write:packages" >> .envrc
                  echo "export GITHUB_TOKEN=$NEW_TOKEN" >> .envrc
                  export GITHUB_TOKEN=$NEW_TOKEN
                fi
                echo "✅ Updated .envrc and exported variables"
              else
                echo "⏭️  Skipping setup. Some commands will be disabled."
              fi
              echo ""
            fi
          fi

          echo "Prebuilt VMs from ghcr.io/''${GH_USER:-aspauldingcode}:"
          echo "  - deboogey-tahoe    (macOS 26.0)"
          echo "  - deboogey-sequoia  (macOS 15.0)"
          echo "  - deboogey-sonoma   (macOS 14.0)"
          echo "  - deboogey-ventura  (macOS 13.0)"
          echo "  - deboogey-monterey (macOS 12.0)"
          echo ""
          echo "Consumer commands:"
          echo "  nix run .#clone-tahoe          # Clone prebuilt VM"
          echo "  nix run .#run-tahoe -- --dir=~ # Run with shared dir"
          echo "  nix run .#ssh-tahoe            # SSH into VM"
          echo ""
          echo "Prebuilt creation (maintainer):"
          echo "  nix run .#login-ghcr           # Authenticate to GHCR"
          echo "  nix run .#create-prebuilt-tahoe -- --push"
          echo ""
        '';
      };
      
      # ============================================
      # Expose VM configs for consuming flakes
      # ============================================
      lib.${system} = {
        vmConfigs = vmConfigs;
      };
    };
}
