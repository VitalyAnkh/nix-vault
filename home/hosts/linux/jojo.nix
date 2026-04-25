{
  config,
  pkgs,
  ...
}:
let
  hostName = "jojo";
in
{
  # Keep this host on the original minimal TUI stack; `home/linux/tui.nix`
  # would also pull in Linux-wide packages and services that are too broad for
  # this low-spec standalone machine.
  imports = [
    ../../base/core
    ../../base/tui
  ];

  programs.ssh.matchBlocks."github.com".identityFile =
    "${config.home.homeDirectory}/.ssh/${hostName}";

  home.packages = with pkgs; [
    emacs-master-pgtk-with-igc
  ];

  home.sessionVariables = {
    NIX_BUILD_CORES = "1";
    GIT_PAGER = "less -FRX";
  };

  programs.git.settings = {
    core = {
      packedGitLimit = "128m";
      packedGitWindowSize = "128m";
      windowMemory = "128m";
      packSizeLimit = "128m";
      threads = "1";
    };

    gc.auto = 0;
    fetch.prune = false;
  };

  home.shellAliases = {
    d = "podman";
    dc = "podman-compose";
    dps = "podman ps";
    dpsa = "podman ps -a";
    dimg = "podman images";
    dexec = "podman exec -it";
    dlogs = "podman logs -f";
  };

  home.file.".tmux.conf".text = ''
    # Minimal tmux configuration for low-spec systems
    set -g history-limit 1000
    set -g default-terminal "screen-256color"

    # Simple status bar
    set -g status-interval 60
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

  systemd.user.startServices = false;
}
