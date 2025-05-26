{ pkgs-unstable, ... }:
{
  environment.systemPackages = with pkgs-unstable; [
    digital
    gnomeExtensions.appindicator
    gnome-extension-manager
    gnomeExtensions.quake-terminal
    gnomeExtensions.clipboard-history
    gnomeExtensions.kimpanel
    clash-verge-rev
    clash-nyanpasu
    # hiddify-app
    flclash
    kdiskmark
    mihomo-party
    #daed
    warp-terminal
    zotero
    kdePackages.okular
    v2raya
    v2rayn
    zulip
  ];
}
