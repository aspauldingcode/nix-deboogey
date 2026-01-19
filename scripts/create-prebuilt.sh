#!/bin/bash
# create-prebuilt.sh - Create and push a prebuilt VM to GHCR
# Usage: create-prebuilt.sh <version> [--push]
#   version: tahoe, sequoia, sonoma, ventura, monterey
#   --push: push to GHCR after creation (requires GITHUB_TOKEN)

set -euo pipefail

# Cleanup trap to ensure background VM is killed on exit
VM_PID=""
cleanup() {
    if [ -n "$VM_PID" ]; then
        echo "Cleaning up VM process (PID: $VM_PID)..."
        kill "$VM_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

VERSION="${1:-}"
DO_PUSH="${2:-}"

if [ -z "$VERSION" ]; then
    echo "Usage: create-prebuilt.sh <version> [--push]"
    echo "  version: tahoe, sequoia, sonoma, ventura, monterey"
    echo "  --push: push to GHCR after creation"
    exit 1
fi

# Version mapping
case "$VERSION" in
    tahoe)
        BASE_IMAGE="ghcr.io/cirruslabs/macos-tahoe-xcode:latest"
        TARGET_IMAGE="ghcr.io/aspauldingcode/deboogey-tahoe:latest"
        ;;
    sequoia)
        BASE_IMAGE="ghcr.io/cirruslabs/macos-sequoia-xcode:latest"
        TARGET_IMAGE="ghcr.io/aspauldingcode/deboogey-sequoia:latest"
        ;;
    sonoma)
        BASE_IMAGE="ghcr.io/cirruslabs/macos-sonoma-xcode:latest"
        TARGET_IMAGE="ghcr.io/aspauldingcode/deboogey-sonoma:latest"
        ;;
    ventura)
        BASE_IMAGE="ghcr.io/cirruslabs/macos-ventura-xcode:latest"
        TARGET_IMAGE="ghcr.io/aspauldingcode/deboogey-ventura:latest"
        ;;
    monterey)
        BASE_IMAGE="ghcr.io/cirruslabs/macos-monterey-xcode:latest"
        TARGET_IMAGE="ghcr.io/aspauldingcode/deboogey-monterey:latest"
        ;;
    *)
        echo "Error: Unknown version '$VERSION'"
        echo "Valid versions: tahoe, sequoia, sonoma, ventura, monterey"
        exit 1
        ;;
esac

VM_NAME="deboogey-$VERSION-build"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Creating Prebuilt: $VERSION ==="
echo "Base image: $BASE_IMAGE"
echo "Target image: $TARGET_IMAGE"
echo "Build VM name: $VM_NAME"
echo ""

# Step 1: Clone from base
echo "=== Step 1: Cloning base image ==="
if tart list --quiet | grep -q "^$VM_NAME$"; then
    echo "Deleting existing build VM..."
    tart delete "$VM_NAME" || true
fi
tart clone "$BASE_IMAGE" "$VM_NAME"
echo "Clone complete."

# Step 1.5: Clean up VMs to avoid system limit
echo ""
echo "=== Step 1.5: Cleaning up VMs to avoid system limit ==="

# Aggressively kill any existing tart run processes that might be holding slots
EXISTING_TART_PIDS=$(pgrep -f "tart run" || true)
if [ -n "$EXISTING_TART_PIDS" ]; then
    echo "Found existing tart run processes, killing them to free up slots..."
    echo "$EXISTING_TART_PIDS" | while read pid; do
        echo "  Killing PID $pid..."
        kill -9 "$pid" 2>/dev/null || true
    done
fi

# Stop all running VMs first
RUNNING_VMS=$(tart list | awk 'NR>1 && $NF=="running" {print $2}')
if [ -n "$RUNNING_VMS" ]; then
    echo "Stopping running VMs..."
    echo "$RUNNING_VMS" | while read vm; do
        echo "  Stopping $vm..."
        tart stop "$vm" 2>/dev/null || true
    done
fi

# Delete OCI cache VMs (they can be re-pulled)
echo "Deleting OCI cache VMs to free up space..."
OCI_VMS=$(tart list | awk 'NR>1 && $1=="OCI" {print $2}')
if [ -n "$OCI_VMS" ]; then
    echo "$OCI_VMS" | while read vm; do
        echo "  Deleting $vm..."
        tart delete "$vm" 2>/dev/null || true
    done
    echo "OCI cache VMs deleted."
fi

# Prune unused images
echo "Pruning unused images..."
tart prune 2>/dev/null || true

echo "Cleanup complete."

# Step 2: Start VM headless
echo ""
echo "=== Step 2: Starting VM for provisioning ==="
echo "Starting $VM_NAME in headless mode..."
tart run "$VM_NAME" --no-graphics &
VM_PID=$!
echo "VM started (PID: $VM_PID)"

# Wait for VM to boot and get IP
echo "Waiting for VM to boot..."
sleep 30

VM_IP=""
for i in {1..60}; do
    VM_IP=$(tart ip "$VM_NAME" 2>/dev/null || true)
    if [ -n "$VM_IP" ]; then
        echo "VM IP: $VM_IP"
        break
    fi
    echo "Waiting for IP... ($i/60)"
    sleep 5
done

if [ -z "$VM_IP" ]; then
    echo "Error: Could not get VM IP after 5 minutes"
    kill $VM_PID 2>/dev/null || true
    exit 1
fi

# Step 3: Provision VM
echo ""
echo "=== Step 3: Provisioning VM (automated password) ==="
echo "Default Cirrus Labs credentials: admin/admin"
echo "Copying provisioning script..."

# Copy and run provisioning script via SSH using SSH_ASKPASS for macOS compatibility
# Note: Cirrus Labs VMs have default user 'admin' with password 'admin'
DISPLAY=:0 SSH_ASKPASS="$SCRIPT_DIR/askpass-admin.sh" SSH_ASKPASS_REQUIRE=force scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    "$SCRIPT_DIR/provision-vm.sh" "admin@$VM_IP:/tmp/provision-vm.sh"

echo "Running provisioning script..."
DISPLAY=:0 SSH_ASKPASS="$SCRIPT_DIR/askpass-admin.sh" SSH_ASKPASS_REQUIRE=force ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    "admin@$VM_IP" "chmod +x /tmp/provision-vm.sh && /tmp/provision-vm.sh"

echo "Provisioning complete."

# Step 4: Stop VM
echo ""
echo "=== Step 4: Stopping VM ==="
# Try graceful shutdown first
DISPLAY=:0 SSH_ASKPASS="$SCRIPT_DIR/askpass-admin.sh" SSH_ASKPASS_REQUIRE=force ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    "admin@$VM_IP" "sudo shutdown -h now" 2>/dev/null || true

sleep 10
tart stop "$VM_NAME" 2>/dev/null || true
kill $VM_PID 2>/dev/null || true

echo "VM stopped."

# Step 5: Rename to final name
echo ""
echo "=== Step 5: Renaming VM ==="
FINAL_VM_NAME="deboogey-$VERSION"
if tart list --quiet | grep -q "^$FINAL_VM_NAME$"; then
    echo "Deleting existing $FINAL_VM_NAME..."
    tart delete "$FINAL_VM_NAME" || true
fi
tart rename "$VM_NAME" "$FINAL_VM_NAME"
echo "Renamed to $FINAL_VM_NAME"

# Step 6: Push to GHCR (if requested)
if [ "$DO_PUSH" = "--push" ]; then
    echo ""
    echo "=== Step 6: Pushing to GHCR ==="
    
    if [ -z "${GITHUB_TOKEN:-}" ]; then
        echo "Error: GITHUB_TOKEN not set"
        echo "Set it with: export GITHUB_TOKEN=ghp_..."
        exit 1
    fi
    
    echo "Pushing $FINAL_VM_NAME to $TARGET_IMAGE..."
    tart push "$FINAL_VM_NAME" "$TARGET_IMAGE"
    echo "Push complete!"
    echo ""
    echo "Image available at: $TARGET_IMAGE"
else
    echo ""
    echo "=== Prebuilt Created (not pushed) ==="
    echo "Local VM: $FINAL_VM_NAME"
    echo ""
    echo "To push to GHCR:"
    echo "  export GITHUB_TOKEN=ghp_..."
    echo "  tart push $FINAL_VM_NAME $TARGET_IMAGE"
fi

echo ""
echo "=== Done ==="
