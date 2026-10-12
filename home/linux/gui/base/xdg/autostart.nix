{
  pkgs,
  lib,
  osConfig,
  ...
}:
let
  # osConfig is null in standalone Home Manager configurations.
  clashVerge = osConfig.programs.clash-verge or { enable = false; };
in
{
  # XDG autostart entries. All of them are globally ordered after the
  # xdg-desktop-portal stack via `systemd.user.units."app-@autostart.service"`
  # in modules/nixos/desktop/xdg.nix, so sandboxed apps (nixpak: firefox,
  # telegram, ...) don't race the portal at login and end up with broken
  # FileChooser/OpenURI until manually restarted.
  xdg.autostart.enable = true;
  # This fixes nixpak sandboxed apps (like firefox) accessing mapped folders correctly
  xdg.autostart.entries = [
    "${pkgs.ghostty}/share/applications/com.mitchellh.ghostty.desktop"
    "${pkgs.kitty}/share/applications/kitty.desktop"
  ]
  # The Clash Verge GUI starts its TUN core, so log in with it while Clash
  # Verge is the proxy backend (hosts/eva/proxy.nix).
  ++ lib.optional clashVerge.enable "${clashVerge.package}/share/applications/clash-verge.desktop"
  ++ [
    # nixpaks
    "${pkgs.nixpaks.firefox}/share/applications/org.mozilla.firefox.desktop"
    "${pkgs.nixpaks.telegram-desktop}/share/applications/org.telegram.desktop.desktop"
    "${pkgs.google-chrome}/share/applications/google-chrome.desktop"
  ];
}
