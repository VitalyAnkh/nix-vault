{
  config,
  pkgs,
  lib,
  ...
}:
let
  hostName = "jojo"; # Low-spec cloud host configuration
in
{
  # This is a minimal standalone home-manager configuration for low-spec cloud hosts
  # Optimized for: 1 core CPU, 2GB RAM, 20GB storage
  # base/tui modules already provide most tools, we just add host-specific settings

  # SSH configuration for this host
  programs.ssh.matchBlocks."github.com" = {
    identityFile = "${config.home.homeDirectory}/.ssh/${hostName}";
  };

  # Additional packages specific to this host
  home.packages = with pkgs; [
    # Emacs with pgtk support (as requested)
    emacs-master-pgtk-with-igc

    # Add any other host-specific packages here if needed
  ];

  # Performance optimizations for low-spec system
  home.sessionVariables = {
    # Reduce Nix memory usage
    NIX_BUILD_CORES = "1"; # Single core optimization

    # Git performance for low-spec
    GIT_PAGER = "less -FRX";
  };

  # Git performance optimizations for low-spec systems
  programs.git.settings = {
    core = {
      # Reduce memory usage
      packedGitLimit = "128m";
      packedGitWindowSize = "128m";
      windowMemory = "128m";
      packSizeLimit = "128m";
      threads = "1"; # Single core optimization
    };

    # Reduce network operations
    gc.auto = 0; # Disable automatic garbage collection
    fetch.prune = false;
  };

  # Container shortcuts (podman is provided by base/tui/container.nix)
  home.shellAliases = {
    # Container shortcuts
    d = "podman";
    dc = "podman-compose";
    dps = "podman ps";
    dpsa = "podman ps -a";
    dimg = "podman images";
    dexec = "podman exec -it";
    dlogs = "podman logs -f";
  };

  # Minimal tmux config for resource efficiency
  home.file.".tmux.conf".text = ''
    # Minimal tmux configuration for low-spec systems
    set -g history-limit 1000  # Reduce history size
    set -g default-terminal "screen-256color"

    # Simple status bar
    set -g status-interval 60  # Update less frequently
    set -g status-left-length 20
    set -g status-right-length 20
    set -g status-left "[#S] "
    set -g status-right "%H:%M"

    # Disable mouse to save resources
    set -g mouse off

    # Simple key bindings
    bind r source-file ~/.tmux.conf
    bind | split-window -h
    bind - split-window -v
  '';

  # Systemd user services - disabled for minimal resource usage
  systemd.user.startServices = false;
}
