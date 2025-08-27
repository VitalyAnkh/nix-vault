{
  pkgs,
  pkgs-unstable,
  ...
}:
{
  home.packages = with pkgs-unstable; [
    # GUI apps
    # e-book viewer(.epub/.mobi/...)
    # do not support .pdf
    foliate

    # instant messaging
    telegram-desktop
    # discord # update too frequently, use the web version instead

    # remote desktop(rdp connect)
    remmina
    freerdp # required by remmina

    flameshot
  ] ++ (
    # my custom hardened packages (available in NixOS and standalone via overlay)
    pkgs.lib.optionals (pkgs ? nixpaks) [
      pkgs.nixpaks.qq
      pkgs.nixpaks.qq-desktop-item
    ]
  ) ++ (
    # bwraps only available in NixOS
    pkgs.lib.optionals (pkgs ? bwraps) [
      pkgs.bwraps.wechat
    ]
  );

  # allow fontconfig to discover fonts and configurations installed through home.packages
  # Install fonts at system-level, not user-level
  fonts.fontconfig.enable = false;
}
