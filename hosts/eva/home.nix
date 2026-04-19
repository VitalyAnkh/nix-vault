{ config, ... }:
let
  hostName = "eva"; # Define your hostname.
in
{
  modules.desktop = {
  };
  modules.editors.emacs = {
    enable = true;
  };

  programs.fish.enable = true;

  programs.ssh.matchBlocks."github.com".identityFile =
    "${config.home.homeDirectory}/.ssh/${hostName}";
}
