{ config, ... }:
let
  hostName = "eva"; # Define your hostname.
in
{
  modules.desktop = {
    hyprland = {
      nvidia = true;
      settings = {
        # Configure your Display resolution, offset, scale and Monitors here, use `hyprctl monitors` to get the info.
        #   highres:      get the best possible resolution
        #   auto:         position automatically
        #   1.5:          scale to 1.5 times
        #   bitdepth,10:  enable 10 bit support
        monitor = "DP-2,highres,auto,1.5,bitdepth,10";
      };
    };
  };
  modules.editors.emacs = {
    enable = true;
  };

  programs.fish.enable = true;

  programs.ssh.matchBlocks."github.com".identityFile =
    "${config.home.homeDirectory}/.ssh/${hostName}";
}
