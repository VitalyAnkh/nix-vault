{ config, ... }:
let
  hostName = "muon";
in
{
  imports = [ ../../linux/gui.nix ];

  modules.desktop.niri.enable = true;
  modules.desktop.nvidia.enable = true;
  modules.editors.emacs.enable = true;

  programs.fish.enable = true;

  programs.ssh.matchBlocks."github.com".identityFile =
    "${config.home.homeDirectory}/.ssh/${hostName}";
}
