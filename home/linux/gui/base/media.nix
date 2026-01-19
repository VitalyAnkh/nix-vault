{
  pkgs,
  pkgs-x64,
  ...
}:
# media - control and enjoy audio/video
{
  home.packages = with pkgs; [
    # audio control
    pavucontrol
    playerctl
    pulsemixer
    imv # simple image viewer
    loupe
    kdePackages.okular

    # video/audio tools
    libva-utils
    vdpauinfo
    vulkan-tools
    mesa-demos
    nvitop
    mpvc
    vlc

    qbittorrent-enhanced

    (pkgs-x64.zoom-us)
  ];

  programs.mpv = {
    enable = true;
    defaultProfiles = [ "gpu-hq" ];
    scripts = [ pkgs.mpvScripts.mpris ];
  };

  services = {
    playerctld.enable = true;
  };
}
