{
  pkgs,
  pkgs-unstable,
  nur-ryan4yin,
  ...
}: {
  home.packages = with pkgs; [
    # creative
    pkgs-unstable.blender # 3d modeling
    # gimp      # image editing, I prefer using figma in browser instead of this one
    inkscape # vector graphics
    pkgs-unstable.krita # digital painting
    musescore # music notation
    pkgs-unstable.reaper # audio production
    pkgs-unstable.sonic-pi # music programming
    pkgs-unstable.supercollider

    # 2d game design
    pkgs-unstable.ldtk # A modern, versatile 2D level editor
    #aseprite # Animated sprite editor & pixel art tool
    pkgs-unstable.godot_4

    pkgs-unstable.freecad-wayland

    # this app consumes a lot of storage, so do not install it currently
    # kicad     # 3d printing, eletrical engineering

    pkgs.nutstore-client
    pkgs.nutstore-nautilus

    # fpga
    pkgs-unstable.python312Packages.apycula # gowin fpga
    pkgs-unstable.yosys # fpga synthesis
    pkgs-unstable.nextpnr # fpga place and route
    pkgs-unstable.openfpgaloader # fpga programming
    #nur-ryan4yin.packages.${pkgs.system}.gowin-eda-edu-ide # app: `gowin-env` => `gw_ide` / `gw_pack` / ...
  ];

  programs = {
    # live streaming
    obs-studio = {
      enable = true;
      plugins = with pkgs.obs-studio-plugins; [
        # screen capture
        wlrobs
        # obs-ndi
        obs-vaapi
        obs-nvfbc
        obs-teleport
        # obs-hyperion
        droidcam-obs
        obs-vkcapture
        obs-gstreamer
        obs-3d-effect
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
        #obs-backgroundremoval
        # advanced-scene-switcher
        obs-pipewire-audio-capture
      ];
    };
  };
}
