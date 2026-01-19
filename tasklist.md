Here's the goal:

1. other nix projects will import this flake for use with their projects.
2. They must be nix users on mac - arm based mac.
3. this flake will provide with them Deboogey in a tahoe vm.
4. tart will be used for making and exposing a vm (and included, xcode).
5. we will clone the default tart vm with xcode pre-installed.
6. we will install deboogey to the vm: git@github.com:theoderoy/Deboogey.git
7. we must make tart mount a shared connection to the host mac - over ssh and a shared directory.


Here's a list of vms:

macos-tahoe-xcode
Published on Jul 5, 2025 by Cirrus Labs in cirruslabs/macos-image-templates
 3.92k
macos-sequoia-base
Published on Sep 24, 2024 by Cirrus Labs in cirruslabs/macos-image-templates
 5.7k
macos-tahoe-base
Published on Jun 15, 2025 by Cirrus Labs
 2.67k
macos-sonoma-base
Published on Sep 20, 2023 by Cirrus Labs in cirruslabs/macos-image-templates
 14.2k
macos-runner
Published on Apr 1, 2024 by Cirrus Labs in cirruslabs/macos-image-templates
 43.7k
macos-tahoe-vanilla
Published on Jun 9, 2025 by Cirrus Labs in cirruslabs/macos-image-templates
 824
macos-sequoia-vanilla
Published on Jun 10, 2024 by Cirrus Labs in cirruslabs/macos-image-templates
 1.63k
macos-sonoma-vanilla
Published on Jun 18, 2023 by Cirrus Labs in cirruslabs/macos-image-templates
 2.42k
macos-sequoia-xcode
Published on Oct 20, 2024 by Cirrus Labs in cirruslabs/macos-image-templates
 6.62k
macos-sonoma-xcode
Published on Sep 20, 2023 by Cirrus Labs in cirruslabs/macos-image-templates
 20.8k
macos-ventura-base
Published on Jul 14, 2022 by Cirrus Labs in cirruslabs/macos-image-templates
 4.73k
macos-ventura-xcode
Published on Jul 27, 2022 by Cirrus Labs in cirruslabs/macos-image-templates
 366k
macos-ventura-vanilla
Published on Jul 14, 2022 by Cirrus Labs in cirruslabs/macos-image-templates
 2.43k
macos-monterey-vanilla
Published on May 3, 2022 by Cirrus Labs in cirruslabs/macos-image-templates
 1.54k
macos-monterey-xcode
Published on May 5, 2022 by Cirrus Labs in cirruslabs/macos-image-templates
 23k
macos-monterey-base
Published on May 4, 2022 by Cirrus Labs in cirruslabs/macos-image-templates
 7.29k



we will tart clone the xcode ones.
we need all xcode on major versions of macos - tahoe, sequoia, sonoma, ventura, monterey, all with xcode in this flake - separated by nix flake package.  

when the user wants to use any of the os, they simply specify which one they want to run. 

tart by default has a clone feature:
tart clone ghcr.io/cirruslabs/macos-sequoia-base:latest sequoia-base
tart run sequoia-base

and here's a cli help for tart:


```
$ tart --help
USAGE: tart <subcommand>

OPTIONS:
  --version               Show the version.
  -h, --help              Show help information.

SUBCOMMANDS:
  create                  Create a VM
  clone                   Clone a VM
  run                     Run a VM
  set                     Modify VM's configuration
  get                     Get a VM's configuration
  list                    List created VMs
  login                   Login to a registry
  logout                  Logout from a registry
  ip                      Get VM's IP address
  exec                    Execute a command in a running VM
  pull                    Pull a VM from a registry
  push                    Push a VM to a registry
  import                  Import VM from a compressed .tvm file
  export                  Export VM to a compressed .tvm file
  prune                   Prune OCI and IPSW caches or local VMs
  rename                  Rename a local VM
  stop                    Stop a VM
  delete                  Delete a VM
  suspend                 Suspend a VM

  See 'tart help <subcommand>' for detailed help.


[nix-shell:~/nix-deboogey]$ tart help clone
OVERVIEW: Clone a VM

Creates a local virtual machine by cloning either a remote or another local virtual machine.

Due to copy-on-write magic in Apple File System, a cloned VM won't actually claim all the space
right away.
Only changes to a cloned disk will be written and claim new space. This also speeds up clones
enormously.

By default, Tart checks available capacity in Tart's home directory and tries to reclaim minimum
possible storage for the cloned image
to fit. This behaviour is called "automatic pruning" and can be disabled by setting
TART_NO_AUTO_PRUNE environment variable.

USAGE: tart clone <source-name> <new-name> [--insecure] [--concurrency <concurrency>] [--prune-limit <n>]

ARGUMENTS:
  <source-name>           source VM name
  <new-name>              new VM name

OPTIONS:
  --insecure              connect to the OCI registry via insecure HTTP protocol
  --concurrency <concurrency>
                          network concurrency to use when pulling a remote VM from the
                          OCI-compatible registry (default: 4)
  --prune-limit <n>       limit automatic pruning to n gigabytes (default: 100)
  --version               Show the version.
  -h, --help              Show help information.


[nix-shell:~/nix-deboogey]$ tart help run
OVERVIEW: Run a VM

USAGE: tart run [<options>] <name>

ARGUMENTS:
  <name>                  VM name

OPTIONS:
  --no-graphics           Don't open a UI window.
        Useful for integrating Tart VMs into other tools.
        Use `tart ip` in order to get an IP for SSHing or VNCing into the VM.
  --serial                Open serial console in /dev/ttySXX
        Useful for debugging Linux Kernel.
  --serial-path <serial-path>
                          Attach an externally created serial console
        Alternative to `--serial` flag for programmatic integrations.
  --no-audio              Disable audio pass-through to host.
  --no-clipboard          Disable clipboard sharing between host and guest.
        Clipboard sharing requires spice-vdagent package on Linux and
        https://github.com/cirruslabs/tart-guest-agent on macOS.
  --recovery              Boot into recovery mode
  --vnc                   Use screen sharing instead of the built-in UI.
        Useful since Screen Sharing supports copy/paste, drag and drop, etc.
        Note that Remote Login option should be enabled inside the VM.
  --vnc-experimental      Use Virtualization.Framework's VNC server instead of the built-in UI.
        Useful since this type of VNC is available in recovery mode and in macOS installation.
        Note that this feature is experimental and there may be bugs present when using VNC.
  --disk <path[:options]> Additional disk attachments with an optional read-only and
                          synchronization options in the form of path[:options] (e.g.
                          --disk="disk.bin", --disk="ubuntu.iso:ro", --disk="/dev/disk0", --disk
                          "ghcr.io/cirruslabs/xcode:16.0:ro" or
                          --disk="nbd://localhost:10809/myDisk:sync=none")
        The disk attachment can be a:

        * path to a disk image file
        * path to a block device (for example, a local SSD on AWS EC2 Mac instances)
        * remote VM name whose disk will be mounted
        * Network Block Device (NBD) URL

        Options are comma-separated and are as follows:

        * ro — attach the specified disk in read-only mode instead of the default read-write (e.g.
        --disk="disk.img:ro")

        * sync=none — disable data synchronization with the permanent storage to increase
        performance at the cost of a higher chance of data loss (e.g. --disk="disk.img:sync=none")

        Learn how to create a disk image using Disk Utility here:
        https://support.apple.com/en-gb/guide/disk-utility/dskutl11888/mac

        To work with block devices, the easiest way is to modify their permissions to be
        accessible to the current user:

        sudo chown $USER /dev/diskX
        tart run sequoia --disk=/dev/diskX

        Warning: after running the chown command above, all software running under the current
        user will be able to access /dev/diskX. If that violates your threat model, we recommend
        avoiding mounting block devices altogether.
  --rosetta <tag>         Attaches a Rosetta share to the guest Linux VM with a specific tag (e.g.
                          --rosetta="rosetta")
        Requires host to be macOS 13.0 (Ventura) with Rosetta installed. The latter can be done
        by running "softwareupdate --install-rosetta" (without quotes) in the Terminal.app.

        Note that you also have to configure Rosetta in the guest Linux VM by following the
        steps from "Mount the Shared Directory and Register Rosetta" section here:
        https://developer.apple.com/documentation/virtualization/running_intel_binaries_in_linux_vms_with_rosetta#3978496
  --dir <[name:]path[:options]>
                          Additional directory shares with an optional read-only and mount tag
                          options in the form of [name:]path[:options] (e.g. --dir="~/src/build"
                          or --dir="~/src/sources:ro")
        Requires host to be macOS 13.0 (Ventura) or newer. macOS guests must be running macOS 13.0
        (Ventura) or newer too.

        Options are comma-separated and are as follows:

        * ro — mount this directory share in read-only mode instead of the default read-write
        (e.g. --dir="~/src/sources:ro")

        * tag=<TAG> — by default, the "com.apple.virtio-fs.automount" mount tag is used for all
        directory shares. On macOS, this causes the directories to be automatically mounted to
        "/Volumes/My Shared Files" directory. On Linux, you have to do it manually: "mount -t
        virtiofs com.apple.virtio-fs.automount /mount/point".

        Mount tag can be overridden by appending tag property to the directory share (e.g.
        --dir="~/src/build:tag=build" or --dir="~/src/build:ro,tag=build"). Then it can be mounted
        via "mount_virtiofs build ~/build" inside guest macOS and "mount -t virtiofs build
        ~/build" inside guest Linux.

        In case of passing multiple directories per mount tag it is required to prefix them with
        names e.g. --dir="build:~/src/build" --dir="sources:~/src/sources:ro". These names will be
        used as directory names under the mounting point inside guests. For the example above it
        will be "/Volumes/My Shared Files/build" and "/Volumes/My Shared Files/sources"
        respectively.
  --nested                Enable nested virtualization if possible
  --net-bridged <interface name>
                          Use bridged networking instead of the default shared (NAT) networking
                          (e.g. --net-bridged=en0 or --net-bridged="Wi-Fi")
        Specify "list" as an interface name (--net-bridged=list) to list the available bridged
        interfaces.
  --net-softnet           Use software networking provided by Softnet instead of the default
                          shared (NAT) networking
        Softnet provides better network isolation and alleviates DHCP shortage on production
        systems. Tart invokes Softnet when this option is specified as a sub-process and
        communicates with it over socketpair(2).

        It is essentially a userspace packet filter which restricts the VM networking and prevents
        a class of security issues, such as ARP spoofing. By default, the VM will only be able to:

        * send traffic from its own MAC-address
        * send traffic from the IP-address assigned to it by the DHCP
        * send traffic to globally routable IPv4 addresses
        * send traffic to gateway IP of the vmnet bridge (this would normally be "bridge100"
        interface)
        * receive any incoming traffic

        In addition, Softnet tunes macOS built-in DHCP server to decrease its lease time from the
        default 86,400 seconds (one day) to 600 seconds (10 minutes). This is especially important
        when you use Tart to clone and run a lot of ephemeral VMs over a period of one day.

        More on Softnet here: https://github.com/cirruslabs/softnet
  --net-softnet-allow <comma-separated CIDRs>
                          Comma-separated list of CIDRs to allow the traffic to when using Softnet
                          isolation (e.g. --net-softnet-allow=192.168.0.0/24)
        This option allows you bypass the private IPv4 address space restrictions imposed by
        --net-softnet.

        For example, you can allow the VM to communicate with the local network with e.g.
        --net-softnet-allow=10.0.0.0/16 or with --net-softnet-allow=0.0.0.0/0 to completely
        disable the destination based restrictions, including VMs bridge isolation.

        When used with --net-softnet-block, the longest prefix match always wins. In case the same
        prefix is both allowed and blocked, blocking takes precedence.

        Implies --net-softnet.
  --net-softnet-block <comma-separated CIDRs>
                          Comma-separated list of CIDRs to block the traffic to when using Softnet
                          isolation (e.g. --net-softnet-block=66.66.0.0/16)
        This option allows you to tighten the IPv4 address space restrictions imposed by
        --net-softnet even further.

        For example --net-softnet-block=0.0.0.0/0 may be used to establish a default deny policy
        that is further relaxed with --net-softnet-allow.

        When used with --net-softnet-allow, the longest prefix match always wins. In case the same
        prefix is both allowed and blocked, blocking takes precedence.

        Implies --net-softnet.
  --net-softnet-expose <comma-separated port specifications>
                          Comma-separated list of TCP ports to expose (e.g. --net-softnet-expose
                          2222:22,8080:80)
        Options are comma-separated and are as follows:

        * EXTERNAL_PORT:INTERNAL_PORT — forward TCP traffic from the EXTERNAL_PORT on a host's
        egress interface (automatically detected and could be Wi-Fi, Ethernet and a VPN interface)
        to the INTERNAL_PORT on guest's IP (as reported by "tart ip")

        Note that for the port forwarding to work correctly:

        * the software in guest listening on INTERNAL_PORT should either listen on 0.0.0.0 or on
        an IP address assigned to that guest
        * connection to the EXTERNAL_PORT should be performed from the local network that the host
        is attached to or from the internet, it's not possible to connect to that forwarded port
        from the host itself

        Another thing to keep in mind is that regular Softnet restrictions will still apply even
        to port forwarding. So if you're planning to access your VM from local network, and your
        local network is 192.168.0.0/24, for example, then add --net-softnet-allow=192.168.0.0/24.
        If you only need port forwarding, to completely disable Softnet restrictions you can use
        --net-softnet-allow=0.0.0.0/0.

        Implies --net-softnet.
  --net-host              Restrict network access to the host-only network
  --root-disk-opts <options>
                          Set the root disk options (e.g. --root-disk-opts="ro" or
                          --root-disk-opts="caching=cached,sync=none")
        Options are comma-separated and are as follows:

        * ro — attach the root disk in read-only mode instead of the default read-write (e.g.
        --root-disk-opts="ro")

        * sync=none — disable data synchronization with the permanent storage to increase
        performance at the cost of a higher chance of data loss (e.g.
        --root-disk-opts="sync=none")

        * sync=fsync — enable data synchronization with the permanent storage, but don't ensure
        that it was actually written (e.g. --root-disk-opts="sync=fsync")

        * sync=full — enable data synchronization with the permanent storage and ensure that it
        was actually written (e.g. --root-disk-opts="sync=full")

        * caching=automatic — allows the virtualization framework to automatically determine
        whether to enable data caching

        * caching=cached — enabled data caching

        * caching=uncached — disables data caching
  --suspendable           Disables audio and entropy devices and switches to only Mac-specific
                          input devices.
        Useful for running a VM that can be suspended via "tart suspend".
  --capture-system-keys   Whether system hot keys should be sent to the guest instead of the host
        If enabled then system hot keys like Cmd+Tab will be sent to the guest instead of the host.
  --no-trackpad           Don't add trackpad as a pointing device on macOS VMs
  --no-pointer            Disable the pointer
  --no-keyboard           Disable the keyboard
  --version               Show the version.
  -h, --help              Show help information.


[nix-shell:~/nix-deboogey]$ tart help list
OVERVIEW: List created VMs

USAGE: tart list [--source <source>] [--format <format>] [--quiet]

OPTIONS:
  --source <source>       Only display VMs from the specified source (e.g. --source local,
                          --source oci).
  --format <format>       Output format: text or json (values: text, json; default: text)
  -q, --quiet             Only display VM names.
  --version               Show the version.
  -h, --help              Show help information.

  [nix-shell:~/nix-deboogey]$ tart help create
OVERVIEW: Create a VM

USAGE: tart create <name> [--from-ipsw <path>] [--linux] [--disk-size <disk-size>] [--disk-format <disk-format>]

ARGUMENTS:
  <name>                  VM name

OPTIONS:
  --from-ipsw <path>      create a macOS VM using path to the IPSW file or URL (or "latest", to fetch
                          the latest supported IPSW automatically)
  --linux                 create a Linux VM
  --disk-size <disk-size> Disk size in GB (default: 50)
  --disk-format <disk-format>
                          Disk image format (values: raw, asif; default: raw)
        ASIF format provides better performance but requires macOS 26 Tahoe or later
  --version               Show the version.
  -h, --help              Show help information.



[nix-shell:~/nix-deboogey]$ tart help create
OVERVIEW: Create a VM

USAGE: tart create <name> [--from-ipsw <path>] [--linux] [--disk-size <disk-size>] [--disk-format <disk-format>]

ARGUMENTS:
  <name>                  VM name

OPTIONS:
  --from-ipsw <path>      create a macOS VM using path to the IPSW file or URL (or "latest", to fetch
                          the latest supported IPSW automatically)
  --linux                 create a Linux VM
  --disk-size <disk-size> Disk size in GB (default: 50)
  --disk-format <disk-format>
                          Disk image format (values: raw, asif; default: raw)
        ASIF format provides better performance but requires macOS 26 Tahoe or later
  --version               Show the version.
  -h, --help              Show help information.


[nix-shell:~/nix-deboogey]$ tart help set
OVERVIEW: Modify VM's configuration

USAGE: tart set <name> [--cpu <cpu>] [--memory <memory>] [--display <display>] [--display-refit] [--no-display-refit] [--random-mac] [--random-serial] [--disk <path>] [--disk-size <disk-size>]

ARGUMENTS:
  <name>                  VM name

OPTIONS:
  --cpu <cpu>             Number of VM CPUs
  --memory <memory>       VM memory size in megabytes
  --display <display>     VM display resolution in a format of WIDTHxHEIGHT[pt|px]. For example,
                          1200x800, 1200x800pt or 1920x1080px. Units are treated as hints and default
                          to "pt" (points) for macOS VMs and "px" (pixels) for Linux VMs when not
                          specified.
  --display-refit/--no-display-refit
                          Whether to automatically reconfigure the VM's display to fit the window
  --random-mac            Generate a new random MAC address for the VM.
  --random-serial         Generate a new random serial number for the macOS VM.
  --disk <path>           Replace the VM's disk contents with the disk contents at path.
  --disk-size <disk-size> Resize the VMs disk to the specified size in GB (note that the disk size can
                          only be increased to avoid losing data)
        See https://tart.run/faq/#disk-resizing for more details.
  --version               Show the version.
  -h, --help              Show help information.


[nix-shell:~/nix-deboogey]$ tart help get
OVERVIEW: Get a VM's configuration

USAGE: tart get <name> [--format <format>]

ARGUMENTS:
  <name>                  VM name.

OPTIONS:
  --format <format>       Output format: text or json (values: text, json; default: text)
  --version               Show the version.
  -h, --help              Show help information.


[nix-shell:~/nix-deboogey]$ tart help login
OVERVIEW: Login to a registry

USAGE: tart login <host> [--username <username>] [--password-stdin] [--insecure] [--no-validate]

ARGUMENTS:
  <host>                  host

OPTIONS:
  --username <username>   username
  --password-stdin        password-stdin
  --insecure              connect to the OCI registry via insecure HTTP protocol
  --no-validate           skip validation of the registry's credentials before logging-in
  --version               Show the version.
  -h, --help              Show help information.


[nix-shell:~/nix-deboogey]$ tart help logout
OVERVIEW: Logout from a registry

USAGE: tart logout <host>

ARGUMENTS:
  <host>                  host

OPTIONS:
  --version               Show the version.
  -h, --help              Show help information.


[nix-shell:~/nix-deboogey]$ tart help ip
OVERVIEW: Get VM's IP address

USAGE: tart ip <name> [--wait <wait>] [--resolver <resolver>]

ARGUMENTS:
  <name>                  VM name

OPTIONS:
  --wait <wait>           Number of seconds to wait for a potential VM booting (default: 0)
  --resolver <resolver>   Strategy for resolving IP address (values: dhcp, arp, agent; default: dhcp)
        By default, Tart is using a "dhcp" resolver which parses the DHCP lease file on host and tries
        to find an entry containing the VM's MAC address. This method is fast and the most reliable,
        but only works for VMs are not using the bridged networking.

        Alternatively, Tart has an "arp" resolver which calls an external "arp" executable and parses
        it's output. This works for VMs using bridged networking and returns their IP, but when they
        generate enough network activity to populate the host's ARP table. Note that "arp" strategy
        won't work for VMs using the Softnet networking.

        A third strategy, "agent" works in all cases reliably, but requires Guest agent for Tart VMs
        (https://github.com/cirruslabs/tart-guest-agent) to be installed inside of a VM.
  --version               Show the version.
  -h, --help              Show help information.


[nix-shell:~/nix-deboogey]$ tart help exec
OVERVIEW: Execute a command in a running VM

Requires Tart Guest Agent running in a guest VM.

Note that all non-vanilla Cirrus Labs VM images already have the Tart Guest Agent installed.

USAGE: tart exec [-i] [-t] <name> <command> ...

ARGUMENTS:
  <name>                  VM name
  <command>               Command to execute

OPTIONS:
  -i                      Attach host's standard input to a remote command
  -t                      Allocate a remote pseudo-terminal (PTY)
  --version               Show the version.
  -h, --help              Show help information.




[nix-shell:~/nix-deboogey]$ tart help pull
OVERVIEW: Pull a VM from a registry

Pulls a virtual machine from a remote OCI-compatible registry. Supports authorization via Keychain (see
"tart login --help"),
Docker credential helpers defined in ~/.docker/config.json or via
TART_REGISTRY_USERNAME/TART_REGISTRY_PASSWORD environment variables.

By default, Tart checks available capacity in Tart's home directory and tries to reclaim minimum
possible storage for the remote image
to fit. This behaviour is called "automatic pruning" and can be disabled by setting TART_NO_AUTO_PRUNE
environment variable.

USAGE: tart pull <remote-name> [--insecure] [--concurrency <concurrency>]

ARGUMENTS:
  <remote-name>           remote VM name

OPTIONS:
  --insecure              connect to the OCI registry via insecure HTTP protocol
  --concurrency <concurrency>
                          network concurrency to use when pulling a remote VM from the OCI-compatible
                          registry (default: 4)
  --version               Show the version.
  -h, --help              Show help information.


[nix-shell:~/nix-deboogey]$ tart help push
OVERVIEW: Push a VM to a registry

USAGE: tart push <local-name> <remote-names> ... [--insecure] [--concurrency <concurrency>] [--chunk-size <chunk-size>] [--label <label> ...] [--populate-cache]

ARGUMENTS:
  <local-name>            local or remote VM name
  <remote-names>          remote VM name(s)

OPTIONS:
  --insecure              connect to the OCI registry via insecure HTTP protocol
  --concurrency <concurrency>
                          network concurrency to use when pushing a local VM to the OCI-compatible
                          registry (default: 4)
  --chunk-size <chunk-size>
                          chunk size in MB if registry supports chunked uploads (default: 0)
        By default monolithic method is used for uploading blobs to the registry but some registries
        support a more efficient chunked method.
        For example, AWS Elastic Container Registry supports only chunks larger than 5MB but GitHub
        Container Registry supports only chunks smaller than 4MB. Google Container Registry on the
        other hand doesn't support chunked uploads at all.
        Please refer to the documentation of your particular registry in order to see if this option is
        suitable for you and what's the recommended chunk size.
  --label <label>         additional metadata to attach to the OCI image configuration in key=value
                          format
        Can be specified multiple times to attach multiple labels.
  --populate-cache        cache pushed images locally
        Increases disk usage, but saves time if you're going to pull the pushed images later.
  --version               Show the version.
  -h, --help              Show help information.


[nix-shell:~/nix-deboogey]$ tart help import
OVERVIEW: Import VM from a compressed .tvm file

USAGE: tart import <path> <name>

ARGUMENTS:
  <path>                  Path to a file created with "tart export".
  <name>                  Destination VM name.

OPTIONS:
  --version               Show the version.
  -h, --help              Show help information.


[nix-shell:~/nix-deboogey]$ tart help export
OVERVIEW: Export VM to a compressed .tvm file

USAGE: tart export <name> [<path>]

ARGUMENTS:
  <name>                  Source VM name.
  <path>                  Path to the destination file.

OPTIONS:
  --version               Show the version.
  -h, --help              Show help information.


[nix-shell:~/nix-deboogey]$ tart help prune
OVERVIEW: Prune OCI and IPSW caches or local VMs

USAGE: tart prune [--entries <entries>] [--older-than <n>] [--space-budget <n>]

OPTIONS:
  --entries <entries>     Entries to remove: "caches" targets OCI and IPSW caches and "vms" targets
                          local VMs. (default: caches)
  --older-than <n>        Remove entries that were last accessed more than n days ago
        For example, --older-than=7 will remove entries that weren't accessed by Tart in the last 7
        days.
  --space-budget <n>      Remove the least recently used entries that do not fit the specified space
                          size budget n, expressed in gigabytes
        For example, --space-budget=50 will effectively shrink all entries to a total size of 50
        gigabytes.
  --version               Show the version.
  -h, --help              Show help information.


[nix-shell:~/nix-deboogey]$ tart help rename
OVERVIEW: Rename a local VM

USAGE: tart rename <name> <new-name>

ARGUMENTS:
  <name>                  VM name
  <new-name>              new VM name

OPTIONS:
  --version               Show the version.
  -h, --help              Show help information.


[nix-shell:~/nix-deboogey]$ tart help stop
OVERVIEW: Stop a VM

USAGE: tart stop <name> [--timeout <timeout>]

ARGUMENTS:
  <name>                  VM name

OPTIONS:
  -t, --timeout <timeout> Seconds to wait for graceful termination before forcefully terminating the VM
                          (default: 30)
  --version               Show the version.
  -h, --help              Show help information.


[nix-shell:~/nix-deboogey]$ tart help delete
OVERVIEW: Delete a VM

USAGE: tart delete <name> ...

ARGUMENTS:
  <name>                  VM name

OPTIONS:
  --version               Show the version.
  -h, --help              Show help information.


[nix-shell:~/nix-deboogey]$ tart help suspend
OVERVIEW: Suspend a VM

USAGE: tart suspend <name>

ARGUMENTS:
  <name>                  VM name

OPTIONS:
  --version               Show the version.
  -h, --help              Show help information.


[nix-shell:~/nix-deboogey]$

```