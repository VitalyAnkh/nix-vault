{
  pkgs,
  pkgs-x64,
  osConfig,
  config,
  lib,
  ...
}:
with lib;
let
  cfg = config.modules.desktop.gaming;
in
{
  options.modules.desktop = {
    gaming = {
      enable = mkEnableOption "Enable desktop gaming support";
    };
  };

  config = mkIf cfg.enable {
    # ==========================================================================
    # Other Optimizations
    # Usage:
    #  UMU game launchers use MangoHud by default; set ENABLE_MANGOHUD=0 in their conf to disable.
    #  Steam - add this as a launch option: `mangohud %command%` / `gamemoderun %command%`
    # ==========================================================================

    # The nix-config-umu-game skill and the launchers it generates rely on
    # umu-launcher, mangohud, winetricks and bbe from this list.

    home.packages =
      (with pkgs; [
        # https://github.com/flightlessmango/MangoHud
        # a simple overlay program for monitoring FPS, temperature, CPU and GPU load, and more.
        mangohud

        # Script to install various redistributable runtime libraries in Wine.
        winetricks
        # https://github.com/Open-Wine-Components/umu-launcher
        # a unified launcher for Windows games on Linux
        umu-launcher

        # Sed-like editor for binary files
        # required by some games to fix problems
        bbe
      ])
      ++ (with pkgs; [
        # Heroic Games Launcher - primarily for Epic Games & GOG
        # https://heroicgameslauncher.com/
        (heroic.override {
          extraPkgs = _pkgs: [
            pkgs.gamescope
          ];
        })
      ]);

    # Game launchers for Epic/GOG/Ubisoft/etc. (use Steam + DWProton for common games)

    # a GUI game launcher for Steam/GoG/Epic/Ubisoft
    # https://lutris.net/games?ordering=-popularity
    programs.lutris = {
      enable = true;
      defaultWinePackage = pkgs-x64.proton-ge-bin;
      steamPackage = osConfig.programs.steam.package;
      protonPackages = [ pkgs-x64.proton-ge-bin ];
      winePackages = with pkgs-x64; [
        wineWow64Packages.full
        wineWow64Packages.stagingFull
      ];
      extraPackages = with pkgs-x64; [
        winetricks
        gamescope
        gamemode
        mangohud
        umu-launcher
      ];
    };
  };
}
