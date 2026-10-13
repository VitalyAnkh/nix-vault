{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.desktop.warp;
  python = pkgs.callPackage ./python.nix { };
  settings = pkgs.writeText "nix-vault-warp-settings.json" (builtins.toJSON cfg.settings);
  # Building the sync runs its tests on the build platform, so a macOS or Linux host
  # cannot get a sync that fails them there.
  tests = pkgs.runCommandLocal "nix-vault-warp-sync-tests" { nativeBuildInputs = [ python ]; } ''
    cp ${./sync.py} sync.py
    cp ${./test_sync.py} test_sync.py
    PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s . -p 'test_*.py'
    touch "$out"
  '';
  sync = pkgs.writeShellApplication {
    name = "nix-vault-warp-sync";
    runtimeInputs = [ python ];
    text = ''
      # Tests: ${tests}
      exec python3 ${./sync.py} \
        --settings ${settings} \
        --config ${lib.escapeShellArg cfg.settingsFile} \
        "$@"
    '';
  };
in
{
  options.modules.desktop.warp = {
    enable = lib.mkEnableOption "the repository's settings in Warp's own settings file";

    settings = lib.mkOption {
      type = (pkgs.formats.toml { }).type;
      default = { };
      example = {
        appearance.text.font_size = 15.0;
      };
      description = ''
        Settings that every activation writes into Warp's settings file. Warp keeps owning
        the file: other keys, and keys later removed from this option, stay as Warp or the
        user left them.
      '';
    };

    settingsFile = lib.mkOption {
      type = lib.types.str;
      default =
        if pkgs.stdenv.hostPlatform.isDarwin then
          "${config.home.homeDirectory}/.warp/settings.toml"
        else
          # The open-source build in pkgs/warp-terminal runs as the warp-oss app.
          "${config.xdg.configHome}/warp-oss/settings.toml";
      description = "Warp's settings file.";
    };
  };

  config = lib.mkIf cfg.enable {
    modules.desktop.warp.settings = {
      # tuios and the Starship prompt draw Nerd Font icons, and Warp uses a single font
      # without fallback. Ghostty and Zed use the same font, which gives CJK text two cells.
      appearance.text.font_name = lib.mkDefault "Maple Mono NF CN";
      # On macOS, Karabiner turns physical Caps Lock+Shift+E into this shortcut
      # (home/darwin/karabiner/README.md).
      global_hotkey.toggle_all_windows = {
        enabled = lib.mkDefault true;
        keybinding = lib.mkDefault "ctrl-shift-E";
      };
    };

    home.packages = [ sync ];

    # Warp rewrites this file from its Settings UI and reloads it when it changes. A store
    # symlink would make it read-only, so the owned keys are merged into it instead. The
    # sync refuses unexpected user state; report it without aborting the activation.
    home.activation.syncWarpSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${lib.getExe sync} $VERBOSE_ARG \
        || warnEcho "Warp settings were not synchronized; fix the error above and run nix-vault-warp-sync."
    '';
  };
}
