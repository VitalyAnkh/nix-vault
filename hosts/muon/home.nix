{ config, ... }:
let
  hostName = "muon"; # Define your hostname.
in
{
  imports = [
    ./xremap.nix  # User-specific xremap configuration
  ];
  modules.desktop = {
    hyprland = {
      nvidia = true;
      settings.source = [
        "${config.home.homeDirectory}/nix-config/hosts/${hostName}/hypr-hardware.conf"
      ];
    };
  };
  modules.editors.emacs = {
    enable = true;
  };

  programs.fish.enable = true;

  programs.ssh.matchBlocks."github.com".identityFile =
    "${config.home.homeDirectory}/.ssh/${hostName}";
}
