{ config, ... }:
let
  hostName = "muon"; # Define your hostname.
in
{
  modules.desktop = {
    nvidia.enable = true;
    hyprland.settings.source = [
      "${config.home.homeDirectory}/nix-config/hosts/${hostName}/hypr-hardware.conf"
    ];
  };
  modules.editors.emacs = {
    enable = true;
  };

  programs.fish.enable = true;

  programs.ssh.matchBlocks."github.com".identityFile =
    "${config.home.homeDirectory}/.ssh/${hostName}";
}
