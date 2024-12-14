{pkgs-unstable, ...}: {
  environment.systemPackages = with pkgs-unstable; [
    gnomeExtensions.appindicator
    gnome-extension-manager
    gnomeExtensions.quake-terminal
    gnomeExtensions.clipboard-history
    gnomeExtensions.kimpanel
    clash-verge-rev
    clash-nyanpasu
    warp-terminal
    zotero
  ];
}
