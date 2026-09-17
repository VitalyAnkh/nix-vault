{
  config,
  lib,
  ...
}:
let
  cfg = config.modules.desktop.hypridle;
in
{
  options.modules.desktop.hypridle = {
    enable = lib.mkEnableOption "hypridle idle daemon for compatible Wayland compositors";
    keyboardBacklightTimeout = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "Seconds of idle before turning off the keyboard backlight.";
    };
    screenOffTimeout = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "Seconds of idle before turning off the monitors (DPMS).";
    };
    lockTimeout = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "Seconds of idle before locking the screen.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion =
          cfg.keyboardBacklightTimeout != null && cfg.screenOffTimeout != null && cfg.lockTimeout != null;
        message = "modules.desktop.hypridle timeouts must be set when hypridle is enabled.";
      }
    ];

    # Keep this opt-in: unsupported compositors (GNOME on eva/muon) make
    # hypridle exit immediately and systemd will restart it forever.
    # Declared in Nix so niri hosts can tune the timeouts below.
    services.hypridle = {
      enable = true;

      settings = {
        general = {
          lock_cmd = "noctalia-shell ipc call lockScreen lock";
          before_sleep_cmd = "noctalia-shell ipc call lockScreen lock";
          # niri already owns org.freedesktop.ScreenSaver and feeds its
          # inhibitors into the compositor idle notifier, so hypridle must not
          # try to claim the interface (it would log "already providing...").
          ignore_dbus_inhibit = true;
        };

        listener = [
          {
            timeout = cfg.keyboardBacklightTimeout;
            # brightnessctl --list / -d kbd_backlight
            on-timeout = "brightnessctl --save --device=kbd_backlight set 0";
            on-resume = "brightnessctl --restore --device=kbd_backlight";
          }
          {
            timeout = cfg.screenOffTimeout;
            ignore_inhibit = true;
            # Some apps keep idle-inhibit active even when they are only sitting
            # on a page, which can prevent screen-off forever. Ignore those
            # inhibitors for screen-off, but skip while an MPRIS player reports
            # active playback.
            condition_cmd = "! playerctl -a status 2>/dev/null | grep -q '^Playing$'";
            condition_retry = 30;
            on-timeout = "niri msg action power-off-monitors";
            on-resume = "niri msg action power-on-monitors";
          }
          {
            timeout = cfg.lockTimeout;
            ignore_inhibit = true;
            # Skip while media is playing, same as screen-off above.
            condition_cmd = "! playerctl -a status 2>/dev/null | grep -q '^Playing$'";
            condition_retry = 30;
            on-timeout = "noctalia-shell ipc call lockScreen lock";
          }
        ];
      };
    };
  };
}
