{
  lib,
  pkgs,
  firefox,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  home.packages =
    (with pkgs; [
      nixpaks.firefox
    ])
    ++ [
      firefox.packages.${system}.firefox-nightly-bin
    ]
    ++ lib.optionals pkgs.stdenv.isx86_64 [
      pkgs.roxy-browser
    ];

  # source code: https://github.com/nix-community/home-manager/blob/master/modules/programs/chromium.nix

  # open-source upstream Chromium, the base for all the browsers below
  programs.chromium.enable = true;
  # the world's most widely used browser, with deep Google account and services integration
  programs.google-chrome.enable = true;
  # Brave's privacy-first build (Shields ad/tracker blocking), minus the crypto/AI extras
  programs.brave-origin.enable = true;
  # Microsoft's browser, with built-in phishing/malware protection, x86_64 build only.
  # Keep the local Wayland/IME/Vulkan flags that the previous wrapProgram used.
  programs.microsoft-edge = {
    enable = pkgs.stdenv.hostPlatform.isx86_64;
    commandLineArgs = [
      "--ozone-platform-hint=auto"
      "--ozone-platform=x11"
      "--gtk-version=4"
      "--enable-wayland-ime"
      "--enable-features=Vulkan"
    ];
  };
}
