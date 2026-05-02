{
  lib,
  config,
  ...
}:
let
  cfg = config.modules.desktop.hypridle;
in
{
  options.modules.desktop.hypridle.enable =
    lib.mkEnableOption "hypridle idle daemon for compatible Wayland compositors";

  config = lib.mkIf cfg.enable {
    xdg.configFile."hypr/hypridle.conf".source = ./hypridle.conf;

    # Hyprland idle daemon. Keep this opt-in because unsupported compositors
    # make hypridle exit immediately and systemd will restart it forever.
    services.hypridle.enable = true;
  };
}
