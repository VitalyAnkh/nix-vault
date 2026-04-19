{ config, ... }:
let
  hostName = "muon"; # Define your hostname.
in
{
  modules.desktop = {
    nvidia.enable = true;
  };
  modules.editors.emacs = {
    enable = true;
  };

  programs.fish.enable = true;

  programs.ssh.matchBlocks."github.com".identityFile =
    "${config.home.homeDirectory}/.ssh/${hostName}";
}
