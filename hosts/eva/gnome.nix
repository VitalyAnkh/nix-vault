{ pkgs-unstable, ... }:
{
  environment.systemPackages = with pkgs-unstable; [
    gnomeExtensions.appindicator
    #gnome-extension-manager
    gnomeExtensions.quake-terminal
    gnomeExtensions.clipboard-history
    gnomeExtensions.kimpanel
    clash-verge-rev
    clash-nyanpasu
    hiddify-app
    flclash
    nekoray
    daed
    warp-terminal
    zotero
    okular
  ];
}
