# VM configuration for each macOS version
# Images hosted at ghcr.io/aspauldingcode with Xcode + Nix + Ammonia + Deboogey
{
  tahoe = {
    image = "ghcr.io/aspauldingcode/deboogey-tahoe:latest";
    baseImage = "ghcr.io/cirruslabs/macos-tahoe-xcode:latest";
    vmName = "deboogey-tahoe";
    macosVersion = "26.0";
    description = "macOS Tahoe (26.0) with Xcode, Nix, Ammonia, Deboogey";
  };
  
  sequoia = {
    image = "ghcr.io/aspauldingcode/deboogey-sequoia:latest";
    baseImage = "ghcr.io/cirruslabs/macos-sequoia-xcode:latest";
    vmName = "deboogey-sequoia";
    macosVersion = "15.0";
    description = "macOS Sequoia (15.0) with Xcode, Nix, Ammonia, Deboogey";
  };
  
  sonoma = {
    image = "ghcr.io/aspauldingcode/deboogey-sonoma:latest";
    baseImage = "ghcr.io/cirruslabs/macos-sonoma-xcode:latest";
    vmName = "deboogey-sonoma";
    macosVersion = "14.0";
    description = "macOS Sonoma (14.0) with Xcode, Nix, Ammonia, Deboogey";
  };
  
  ventura = {
    image = "ghcr.io/aspauldingcode/deboogey-ventura:latest";
    baseImage = "ghcr.io/cirruslabs/macos-ventura-xcode:latest";
    vmName = "deboogey-ventura";
    macosVersion = "13.0";
    description = "macOS Ventura (13.0) with Xcode, Nix, Ammonia, Deboogey";
  };
  
  monterey = {
    image = "ghcr.io/aspauldingcode/deboogey-monterey:latest";
    baseImage = "ghcr.io/cirruslabs/macos-monterey-xcode:latest";
    vmName = "deboogey-monterey";
    macosVersion = "12.0";
    description = "macOS Monterey (12.0) with Xcode, Nix, Ammonia, Deboogey";
  };
}
