{
  config,
  pkgs,
  lib,
  ...
}:
let
  hostName = "revachol";
in
{
  imports = [ ../../linux/gui.nix ];

  programs = {
    fish.enable = true;
    git.enable = true;
    ssh.settings."github.com".IdentityFile = "${config.home.homeDirectory}/.ssh/${hostName}";
  };

  programs.man = {
    enable = false;
    generateCaches = false;
  };

  home.packages = with pkgs; [
    fd
    bat
    eza
    zoxide
    fzf
    htop
    btop
    curl
    wget
    nmap
    emacs-master-pgtk-with-igc
    emacs-lsp-booster
    fcitx5-rime
    nutstore-client
  ];

  home.shellAliases = {
    ll = "eza -la";
    la = "eza -a";
    ls = "eza";
    cat = "bat";
  };

  home.sessionVariables = {
    EDITOR = lib.mkDefault "hx";
    TERMINAL = lib.mkDefault "ghostty";
  };
}
