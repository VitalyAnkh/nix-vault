{ config, lib, ... }:
let
  cfg = config.services.desktopManager.gnome;
in
{
  config = lib.mkIf cfg.enable {
    # GNOME sets `i18n.inputMethod.type = mkDefault "ibus"`. We prefer fcitx5.
    i18n.inputMethod.type = "fcitx5";
    i18n.inputMethod.fcitx5.waylandFrontend = true;
  };
}
