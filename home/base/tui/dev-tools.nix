{
  lib,
  pkgs,
  ...
}:
{
  #############################################################
  # Basic settings for development environment.
  #############################################################

  home.packages =
    with pkgs;
    [
      colmena
      tokei

      # Databases
      mycli
      pgcli
      mongosh
      sqlite

      # Embedded development
      minicom

      # AI and media tooling
      python313Packages.huggingface-hub
      yt-dlp

      # Terminal and general development
      tmux
      devbox
      bfg-repo-cleaner
      k6
      pnpm
      bun
      meson
      mesonlsp
      exercism
      wakatime-cli
      duckdb
      (lib.lowPrio wrangler)
      gitleaks
    ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      conda
      git-trim
    ];

  programs = {
    direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableZshIntegration = true;
      enableBashIntegration = true;
      enableNushellIntegration = true;
    };
  };
}
