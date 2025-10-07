{
  pkgs-unstable,
  nix-gaming,
  ...
}:
{
  home.packages = with pkgs-unstable; [
    prismlauncher # A free, open source launcher for Minecraft
    winetricks # A script to install DLLs needed to work around problems in Wine

    # some games
    beyond-all-reason
    warzone2100
    cataclysm-dda-git
    zeroad-unwrapped
    zeroad-data
    nix-gaming.packages.${pkgs-unstable.system}.osu-lazer-bin
  ];
}
