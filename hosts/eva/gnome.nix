{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    digital
    gnomeExtensions.appindicator
    gnome-extension-manager
    gnomeExtensions.quake-terminal
    gnomeExtensions.clipboard-history
    gnomeExtensions.kimpanel
    gnomeExtensions.user-themes
    gnome-screenshot-portal
    clash-verge-rev
    clash-nyanpasu
    # hiddify-app
    # flclash was removed from nixpkgs (low usage / unmaintained). Keep
    # `.config/flclash` preserved so existing data stays on /persistent.
    kdiskmark
    # clash-party
    #daed
    warp-terminal
    # waveterm was removed from current nixpkgs (EOL Electron application).
    zotero
    kdePackages.okular
    v2raya
  ];
}
