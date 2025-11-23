{
  lib,
  pkgs,
  blender-bin,
  ...
}:
{
  home.packages =
    with pkgs;
    [
      # creative
      # gimp      # image editing, I prefer using figma in browser instead of this one
      inkscape # vector graphics
      krita # digital painting
      musescore # music notation
      # reaper # audio production
      # sonic-pi # music programming

      # 2d game design
      aseprite # Animated sprite editor & pixel art tool
      godot_4

      # this app consumes a lot of storage, so do not install it currently
      kicad # 3d printing, electrical engineering
      nutstore-client
      nutstore-nautilus

      logisim-evolution
      bottles
      wineWowPackages.waylandFull
      # wineWowPackages.stagingFull
    ]
    ++ (lib.optionals pkgs.stdenv.isx86_64 [
      # https://github.com/edolstra/nix-warez/blob/master/blender/flake.nix
      (
        blender-bin.packages.${pkgs.stdenv.hostPlatform.system}.blender_4_5
        or blender-bin.packages.${pkgs.stdenv.hostPlatform.system}.blender_4_2
      ) # 3d modeling

      ldtk # A modern, versatile 2D level editor
    ]);

  programs = {
    # live streaming
    obs-studio = {
      enable = pkgs.stdenv.isx86_64;
      plugins =
        with pkgs.obs-studio-plugins;
        [
          # screen capture
          wlrobs
          # obs-ndi
          # obs-nvfbc
          obs-teleport
          # obs-hyperion
          droidcam-obs
          obs-vkcapture
          obs-gstreamer
          input-overlay
          obs-multi-rtmp
          obs-source-clone
          obs-shaderfilter
          obs-source-record
          obs-livesplit-one
          looking-glass-obs
          obs-vintage-filter
          obs-command-source
          obs-move-transition
          obs-backgroundremoval
          # advanced-scene-switcher
          obs-pipewire-audio-capture
        ]
        ++ (lib.optionals pkgs.stdenv.isx86_64 [
          obs-vaapi
          obs-3d-effect
        ]);
    };
  };
}
