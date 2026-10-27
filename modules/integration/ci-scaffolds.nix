{ config, lib, pkgs, ... }:

let
  cfg = config.nix-deboogey.integrations;
  tartCfg = config.nix-deboogey.tart;

  githubActionsScaffold = ''
name: Tart CI Runner
on: [push, pull_request]
jobs:
  tart-job:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4
      - name: Run Build in Tart VM
        run: |
          tart pull ghcr.io/aspauldingcode/nix-deboogey/macos-tahoe-deboogey:latest
          tart clone ghcr.io/aspauldingcode/nix-deboogey/macos-tahoe-deboogey:latest ci-runner-$GITHUB_RUN_ID
          trap 'tart stop ci-runner-$GITHUB_RUN_ID || true; tart delete ci-runner-$GITHUB_RUN_ID || true' EXIT
          tart run ci-runner-$GITHUB_RUN_ID --dir host_work:$PWD --no-graphics &
          sleep 10
          tart exec ci-runner-$GITHUB_RUN_ID echo "Tart runner operational"
'';

  gitlabRunnerScaffold = ''
[[runners]]
  name = "tart-executor"
  url = "https://gitlab.com/"
  executor = "custom"
  [runners.custom]
    prepare_exec = "tart clone ghcr.io/aspauldingcode/nix-deboogey/macos-sequoia-deboogey:latest"
    run_exec = "tart run"
    cleanup_exec = "tart delete"
'';

  buildkiteScaffold = ''
steps:
  - label: ":apple: Run macOS tests in Tart"
    command: |
      tart pull ghcr.io/aspauldingcode/nix-deboogey/macos-sonoma-deboogey:latest
      tart run ghcr.io/aspauldingcode/nix-deboogey/macos-sonoma-deboogey:latest --dir host:$BUILDKITE_BUILD_CHECKOUT_PATH --no-graphics
'';
in
{
  options.nix-deboogey.integrations = {
    cirrusCli = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install Cirrus CLI via Homebrew (cirruslabs/cli/cirrus).";
    };

    packer = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install HashiCorp Packer for Tart VM template builds.";
    };

    githubActions = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Generate Tart runner workflow scaffold for GitHub Actions.";
    };

    gitlabRunner = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Generate GitLab CI runner custom executor configuration scaffold.";
    };

    buildkite = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Generate Buildkite pipeline step scaffold for Tart execution.";
    };
  };

  config = lib.mkIf tartCfg.enable {
    homebrew = {
      taps =
        lib.optional cfg.cirrusCli "cirruslabs/cli"
        ++ lib.optional cfg.packer "hashicorp/tap";

      brews =
        lib.optional cfg.cirrusCli "cirruslabs/cli/cirrus"
        ++ lib.optional cfg.packer "hashicorp/tap/packer";
    };

    # Activation script to generate scaffold files into ~/tart-integrations
    system.activationScripts.nix-deboogey-ci-scaffolds.text = lib.mkIf (cfg.githubActions || cfg.gitlabRunner || cfg.buildkite) ''
      SCAFFOLD_DIR="$HOME/tart-integrations"
      echo "==> Scaffolding Tart CI configuration files in $SCAFFOLD_DIR..."
      mkdir -p "$SCAFFOLD_DIR"

      ${lib.optionalString cfg.githubActions ''
        mkdir -p "$SCAFFOLD_DIR/github-actions"
        cat << 'EOF' > "$SCAFFOLD_DIR/github-actions/tart-runner.yml"
${githubActionsScaffold}EOF
      ''}

      ${lib.optionalString cfg.gitlabRunner ''
        mkdir -p "$SCAFFOLD_DIR/gitlab"
        cat << 'EOF' > "$SCAFFOLD_DIR/gitlab/config.toml"
${gitlabRunnerScaffold}EOF
      ''}

      ${lib.optionalString cfg.buildkite ''
        mkdir -p "$SCAFFOLD_DIR/buildkite"
        cat << 'EOF' > "$SCAFFOLD_DIR/buildkite/pipeline.yml"
${buildkiteScaffold}EOF
      ''}
    '';
  };
}
