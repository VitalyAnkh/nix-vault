{
  lib,
  pkgs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;

  microsoft-edge =
    if pkgs.stdenv.isAarch64 then
      null
    else
      pkgs.symlinkJoin {
        name = "microsoft-edge-wrapped";
        paths = [ pkgs.microsoft-edge ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/microsoft-edge \
            --add-flags "--ozone-platform-hint=auto" \
            --add-flags "--ozone-platform=x11" \
            --add-flags "--gtk-version=4" \
            --add-flags "--enable-wayland-ime" \
            --add-flags "--enable-features=Vulkan"
        '';
      };
in
{
  home.packages = [
    nixpaks.firefox
    firefox.packages.${system}.firefox-nightly-bin
  ]
  ++ lib.optionals (microsoft-edge != null) [ microsoft-edge ];

  # source code: https://github.com/nix-community/home-manager/blob/master/modules/programs/chromium.nix
  programs.google-chrome = {
    enable = true;
    package = if pkgs.stdenv.isAarch64 then pkgs.chromium else pkgs.google-chrome;
  };
}
