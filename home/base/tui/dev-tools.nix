{ lib, pkgs, ... }:
{
  #############################################################
  #
  #  Basic settings for development environment
  #
  #  Please avoid to install language specific packages here(globally),
  #  instead, install them:
  #     1. per IDE, such as `programs.neovim.extraPackages`
  #     2. per-project, using https://github.com/the-nix-way/dev-templates
  #
  #############################################################

  home.packages =
    with pkgs;
    [
      colmena # nixos's remote deployment tool

      tokei # count lines of code, alternative to cloc

      # db related
      mycli
      pgcli
      mongosh
      sqlite

      # embedded development
      minicom

      # ai related
      python313Packages.huggingface-hub # huggingface-cli

      # terminal
      tmux

      # misc
      devbox
      bfg-repo-cleaner # remove large files from git history
      k6 # load testing tool

      # web tools
      pnpm
      bun

      meson
      mesonlsp

      # solve coding extercises - learn by doing
      exercism

      wakatime-cli

      # openai codex
      # codex

      duckdb

      # cloudflare
      (lib.lowPrio wrangler)

      # Secret scanner for git repos
      gitleaks
    ]
    ++ (lib.optionals pkgs.stdenv.isLinux [
      # need to run `conda-install` before using it
      # need to run `conda-shell` before using command `conda`
      conda

      # Automatically trims your branches whose tracking remote refs are merged or gone.
      # Install via homebrew on macOS.
      git-trim
    ]);

  programs = {
    direnv = {
      enable = true;
      nix-direnv.enable = true;

      enableZshIntegration = true;
      enableBashIntegration = true;
      enableNushellIntegration = true;
      # VR_TODO: it's not needed, but why?
      # enableFishIntegration = true;
    };
  };
}
