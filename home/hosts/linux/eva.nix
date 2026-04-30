{ config, ... }:
let
  hostName = "eva";
  mkSymlink = config.lib.file.mkOutOfStoreSymlink;
in
{
  imports = [ ../../linux/gui.nix ];

  modules.desktop.gaming.enable = true;
  modules.desktop.niri.enable = true;
  modules.desktop.nvidia.enable = true;

  modules.editors.emacs.enable = true;

  programs.fish.enable = true;

  programs.ssh.matchBlocks."github.com".identityFile =
    "${config.home.homeDirectory}/.ssh/${hostName}";

  xdg.configFile."niri/niri-hardware.kdl".source =
    mkSymlink "${config.home.homeDirectory}/nix-vault/hosts/${hostName}/niri-hardware.kdl";
}
