{
  lib,
  pkgs,
  ...
}:
let
  isX86_64Linux = pkgs.stdenv.isLinux && pkgs.stdenv.isx86_64;
  osuLazerBin = pkgs."osu-lazer-bin" or null;
in
{
  home.packages = lib.optionals isX86_64Linux (
    (with pkgs; [
      prismlauncher # A free, open source launcher for Minecraft
      winetricks # A script to install DLLs needed to work around problems in Wine

      # some games
      beyond-all-reason
      warzone2100
      cataclysm-dda-git
      zeroad-unwrapped
      zeroad-data
    ])
    ++ lib.optional (osuLazerBin != null) osuLazerBin
  );
}
