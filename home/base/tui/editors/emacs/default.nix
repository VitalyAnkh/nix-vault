# ==============================================
# Based on doomemacs's author's config:
#   https://github.com/hlissner/dotfiles/blob/master/modules/editors/emacs.nix
#
# Emacs Tutorials:
#  1. Official: <https://www.gnu.org/software/emacs/tour/index.html>
#  2. Doom Emacs: <https://github.com/doomemacs/doomemacs/blob/master/docs/index.org>
#
{
  config,
  lib,
  pkgs,
  doomemacs,
  ...
}:
with lib;
let
  cfg = config.modules.editors.emacs;
  # Linux: do not use emacs-nox here, which makes the mouse wheel work abnormally in terminal mode.
  # pgtk (pure gtk) build add native support for wayland.
  # https://www.gnu.org/savannah-checkouts/gnu/emacs/emacs.html#Releases
  # emacsPkg = myEmacsPackagesFor pkgs.emacs30-pgtk;
  # macOS: macport adds some native features based on GNU Emacs 29
  # https://bitbucket.org/mituharu/emacs-mac/src/master/README-mac
  # emacsPkg = myEmacsPackagesFor pkgs.emacs29;
  emacsPkg = pkgs.emacs-master-pgtk-with-igc;
  envExtra = lib.mkAfter ''
    export PATH=${lib.escapeShellArg "${config.xdg.configHome}/emacs/bin"}:"$PATH"
  '';
  shellAliases = {
    e = "emacsclient --create-frame"; # gui
    et = "emacsclient --create-frame --tty"; # terminal
  };
  librime-dir = "${config.xdg.dataHome}/emacs/librime";
  parinfer-rust-lib-dir = "${config.xdg.dataHome}/emacs/parinfer-rust";
  myEmacsPackagesFor =
    emacs:
    ((pkgs.emacsPackagesFor emacs).emacsWithPackages (epkgs: [
      epkgs.vterm
    ]));
  # to make this symlink work, we need to git clone this repo to your home directory.
  #configPath = "${config.home.homeDirectory}/nix-config/home/base/tui/editors/emacs/doom";
  configPath = "${config.home.homeDirectory}/projects/dev/emacs-projects/doom";
  # The Doom configuration unpins straight.el, whose build cache records each
  # dependency as (name . minimum-version). Doom's autoload walker for `doom sync`
  # expects names and fails on these pairs; the patch reads them with
  # straight--get-dependencies and keeps only the names.
  doomSource = pkgs.applyPatches {
    name = "doomemacs";
    src = doomemacs;
    patches = [ ./doom-straight-dependency-versions.patch ];
  };
in
{
  options.modules.editors.emacs = {
    enable = mkEnableOption "Emacs Editor";
    doom.enable = mkEnableOption "Doom Emacs configuration and dependencies" // {
      default = true;
    };
    daemon.enable = mkEnableOption "the Emacs daemon with the user session" // {
      default = pkgs.stdenv.isDarwin;
      defaultText = literalExpression "pkgs.stdenv.isDarwin";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      home.packages = [
        emacsPkg
        pkgs.emacs-lsp-booster
      ];
      home.shellAliases = shellAliases;
      programs.nushell.shellAliases = shellAliases;
    }

    (mkIf cfg.doom.enable {
      home.packages = with pkgs; [
        ## Doom dependencies
        git
        (ripgrep.override { withPCRE2 = true; })
        gnutls # for TLS connectivity

        ## Optional dependencies
        fd # faster projectile indexing
        imagemagick # for image-dired
        zstd # for undo-fu-session/undo-tree compression

        # go-mode
        # gocode # project archived, use gopls instead

        ## Module dependencies
        # :checkers spell
        # (aspellWithDicts (ds: with ds; [en en-computers en-science]))
        # :tools editorconfig
        editorconfig-core-c # per-project style config
        # :tools lookup & :lang org +roam
        sqlite
        # :lang latex & :lang org (latex previews)
        # texlive.combined.scheme-medium
      ];

      programs.bash.bashrcExtra = envExtra;
      programs.zsh.envExtra = envExtra;
      programs.fish.shellInit = lib.mkAfter ''
        fish_add_path --path ${lib.escapeShellArg "${config.xdg.configHome}/emacs/bin"}
      '';

      xdg.configFile."doom".source = config.lib.file.mkOutOfStoreSymlink configPath;

      home.activation.installDoomEmacs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run mkdir -p ${lib.escapeShellArg "${config.xdg.configHome}/emacs"}
        run ${pkgs.rsync}/bin/rsync -avz --chmod=D2755,F744 \
          ${lib.escapeShellArg "${doomSource}/"} ${lib.escapeShellArg "${config.xdg.configHome}/emacs/"}

        # librime for emacs-rime
        run mkdir -p ${lib.escapeShellArg librime-dir}
        run ${pkgs.rsync}/bin/rsync -avz --chmod=D2755,F744 \
          "${pkgs.librime}/" ${lib.escapeShellArg "${librime-dir}/"}

        # libparinfer_rust for emacs' parinfer-rust-mode
        run mkdir -p ${lib.escapeShellArg parinfer-rust-lib-dir}
        run ${pkgs.rsync}/bin/rsync -avz --chmod=D2755,F744 \
          "${pkgs.vimPlugins.parinfer-rust}/lib"/libparinfer_rust.* \
          ${lib.escapeShellArg "${parinfer-rust-lib-dir}/parinfer-rust.so"}

        # Emacs ignores the configuration directory above while ~/.emacs.d exists,
        # which Emacs itself creates when it runs before Doom is installed.
        if [[ -d "$HOME/.emacs.d" && ! -L "$HOME/.emacs.d" && -z "$(ls -A "$HOME/.emacs.d")" ]]; then
          run rmdir "$HOME/.emacs.d"
        fi
        for init in "$HOME/.emacs.d" "$HOME/.emacs" "$HOME/.emacs.el"; do
          if [[ -e "$init" || -L "$init" ]]; then
            warnEcho "Emacs loads $init instead of Doom; move it away to use Doom."
          fi
        done
      '';
    })

    (mkIf (cfg.daemon.enable && pkgs.stdenv.isLinux) {
      services.emacs = {
        enable = true;
        package = emacsPkg;
        # client = {
        #   enable = true;
        #   arguments = [ " --create-frame" ];
        # };
        startWithUserSession = true;
      };
    })

    (mkIf (cfg.daemon.enable && pkgs.stdenv.isDarwin) {
      launchd.enable = true;
      launchd.agents.emacs = {
        enable = true;
        config = {
          ProgramArguments = [
            "${pkgs.bash}/bin/bash"
            "-l"
            "-c"
            "exec ${emacsPkg}/bin/emacs --fg-daemon"
          ];
          StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/emacs-daemon.stderr.log";
          StandardOutPath = "${config.home.homeDirectory}/Library/Logs/emacs-daemon.stdout.log";
          RunAtLoad = true;
          KeepAlive = true;
        };
      };
    })
  ]);
}
