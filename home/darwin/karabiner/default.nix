{
  config,
  lib,
  pkgs,
  ...
}:
let
  rules = ./linux-shortcuts.json;
  emacs = config.modules.editors.emacs;
  copyApps = config.targets.darwin.copyApps;
  sync = pkgs.writeShellApplication {
    name = "nix-vault-karabiner-sync";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${./sync.py} \
        --rules ${rules} \
        --config ${lib.escapeShellArg "${config.xdg.configHome}/karabiner/karabiner.json"} \
        --home ${lib.escapeShellArg config.home.homeDirectory} \
        "$@"
    '';
  };
in
{
  options.modules.desktop.karabiner.enable =
    lib.mkEnableOption "the repository's app-specific Linux-style Karabiner shortcuts";

  config = lib.mkIf config.modules.desktop.karabiner.enable {
    # The Ctrl+Shift+Q rule opens ~/Applications/Home Manager Apps/Emacs.app. The
    # frames of an Emacs daemon have no app bundle, so the rule would start a
    # second Emacs instead of showing them.
    assertions = [
      {
        assertion = emacs.enable && !emacs.daemon.enable;
        message = "modules.desktop.karabiner: the Ctrl+Shift+Q rule opens Emacs.app; it needs modules.editors.emacs.enable without daemon.enable. Change the rule before changing these options.";
      }
      {
        assertion = copyApps.enable && copyApps.directory == "Applications/Home Manager Apps";
        message = "modules.desktop.karabiner: the Ctrl+Shift+Q rule opens ~/Applications/Home Manager Apps/Emacs.app, which targets.darwin.copyApps provides.";
      }
    ];

    home.packages = [ sync ];

    xdg.configFile."karabiner/assets/complex_modifications/nix-vault-linux-shortcuts.json".source =
      rules;

    # Karabiner rewrites this file and watches its directory. A store symlink for
    # karabiner.json would prevent reliable reloads and changes in its Settings UI.
    # The sync refuses unexpected user state; report it without aborting the rest
    # of Home Manager and nix-darwin activation. It runs after copyApps, so that its
    # warning about a missing app reflects the new copy.
    home.activation.syncKarabiner = lib.hm.dag.entryAfter [ "writeBoundary" "copyApps" ] ''
      run ${lib.getExe sync} $VERBOSE_ARG \
        || warnEcho "Karabiner configuration was not synchronized; fix the error above and run nix-vault-karabiner-sync."
    '';
  };
}
