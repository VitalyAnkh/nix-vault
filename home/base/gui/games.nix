{
  lib,
  pkgs,
  pkgs-stable,
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
      # GCC 16, the default compiler in nixpkgs unstable, fails to build these two
      # and the cache has no build; 26.05 builds them with GCC 15.
      pkgs-stable.warzone2100
      pkgs-stable.cataclysm-dda-git
      zeroad-unwrapped
      zeroad-data
    ])
    ++ lib.optional (osuLazerBin != null) osuLazerBin
  );
}
