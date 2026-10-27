{ config, lib, pkgs, ... }:

let
  cfg = config.nix-deboogey.tart;
  sshCfg = cfg.defaults.ssh;
  orchardCfg = config.nix-deboogey.orchard or {};
in
{
  config = lib.mkIf (cfg.enable && sshCfg.enable) {
    # Install sshpass via Homebrew tap
    homebrew = {
      taps = [ "cirruslabs/cli" ];
      brews = [ "cirruslabs/cli/sshpass" ];
    };

    # Inject interactive shell helpers for Tart SSH and SCP
    environment.interactiveShellInit = ''
      # --- nix-deboogey Tart SSH Helpers ---
      tart-ssh() {
        if [ -z "''${1:-}" ]; then
          echo "Usage: tart-ssh <vm-name> [command...]" >&2
          return 1
        fi
        local vm="$1"
        shift
        local ip
        ip="$(tart ip "$vm" 2>/dev/null || true)"
        if [ -z "$ip" ]; then
          echo "❌ Error: Could not obtain IP address for Tart VM '$vm'." >&2
          echo "Make sure the VM is running and the Tart guest agent is responsive." >&2
          return 1
        fi
        echo "Connecting to $vm ($ip) as ${sshCfg.user}..." >&2
        sshpass -p "${sshCfg.password}" ssh \
          -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null \
          -o LogLevel=ERROR \
          "${sshCfg.user}@$ip" "$@"
      }

      tart-scp() {
        sshpass -p "${sshCfg.password}" scp \
          -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null \
          -o LogLevel=ERROR \
          "$@"
      }
    '';

    # Configure SSH ProxyJump for Orchard if controller mode is active
    system.activationScripts.nix-deboogey-ssh-orchard.text = lib.mkIf (orchardCfg.enable or false && orchardCfg.mode or "none" == "controller") ''
      SSH_DIR="$HOME/.ssh"
      mkdir -p "$SSH_DIR"
      CONFIG_FILE="$SSH_DIR/config"
      HEADER="# --- nix-deboogey Orchard ProxyJump ---"

      if ! grep -q "$HEADER" "$CONFIG_FILE" 2>/dev/null; then
        echo "Adding Orchard SSH ProxyJump config to $CONFIG_FILE..."
        cat << 'EOF' >> "$CONFIG_FILE"

# --- nix-deboogey Orchard ProxyJump ---
Host *.orchard
  ProxyJump admin@localhost:2222
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
EOF
      fi
    '';
  };
}
