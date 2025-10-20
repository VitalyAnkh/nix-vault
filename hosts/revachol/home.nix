{
  config,
  pkgs,
  lib,
  ...
}:
let
  hostName = "revachol"; # Non-NixOS host configuration
in
{
  # This is a standalone home-manager configuration for non-NixOS systems
  # It can be used on any Linux distribution with Nix installed

  # Enable some basic programs
  programs = {
    fish.enable = true;
    git.enable = true;

    # SSH configuration for this host
    ssh.matchBlocks."github.com" = {
      identityFile = "${config.home.homeDirectory}/.ssh/${hostName}";
    };
  };

  # Disable man for it causing infinite recursion issue
  programs.man = {
    enable = false;
    generateCaches = false;
  };

  # Host-specific packages
  home.packages = with pkgs; [
    # Development tools that work on non-NixOS
    ripgrep
    fd
    bat
    eza
    zoxide
    fzf

    # System monitoring
    htop
    btop

    # Network tools
    curl
    wget
    nmap

    # Custom packages from pkgs directory (added via overlay)
    emacs-master-pgtk-with-igc
    emacs-lsp-booster
    fcitx5-rime
    nutstore-client
    # nutstore-nautilus # Only if using nautilus file manager
  ];

  # Shell aliases
  home.shellAliases = {
    ll = "eza -la";
    la = "eza -a";
    ls = "eza";
    cat = "bat";
  };

  # Environment variables for non-NixOS systems
  home.sessionVariables = {
    EDITOR = lib.mkDefault "hx"; # helix editor
    # BROWSER is already set in home/linux/base/shell.nix
    # Override it if needed with lib.mkForce
    TERMINAL = lib.mkDefault "ghostty";
  };
}
