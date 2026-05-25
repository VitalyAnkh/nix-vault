{ config, lib, ... }:
let
  cfg = config.modules.desktop.uinput;
  hmUsers = config.home-manager.users or { };
  userNeedsUinput = userConfig: userConfig.modules.desktop.ydotoold.enable or false;
  homeManagerNeedsUinput = lib.any userNeedsUinput (lib.attrValues hmUsers);
in
{
  options.modules.desktop.uinput.enable = lib.mkEnableOption ''
    host-level uinput support for user-space input injection tools
  '';

  # Host-level support for user-space input injection tools such as ydotoold.
  # Home Manager can manage the user service, but loading the kernel module and
  # installing the /dev/uinput udev rule must happen in NixOS.
  config = lib.mkIf (cfg.enable || homeManagerNeedsUinput) {
    hardware.uinput.enable = true;
  };
}
