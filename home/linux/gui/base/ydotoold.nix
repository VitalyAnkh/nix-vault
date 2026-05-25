{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.desktop.ydotoold;
  clientSocketPath =
    lib.replaceStrings
      [
        "%h"
        "%t"
      ]
      [
        "$HOME"
        "$XDG_RUNTIME_DIR"
      ]
      cfg.socketPath;
in
{
  options.modules.desktop.ydotoold = {
    enable = lib.mkEnableOption "ydotool user input daemon";
    socketPath = lib.mkOption {
      type = lib.types.str;
      default = "%t/.ydotool_socket";
      description = "Socket path for the per-user ydotoold instance.";
    };
  };

  config = lib.mkIf (cfg.enable && pkgs.stdenv.isLinux) {
    home.packages = [ pkgs.ydotool ];
    home.sessionVariables.YDOTOOL_SOCKET = clientSocketPath;
    systemd.user.sessionVariables.YDOTOOL_SOCKET = clientSocketPath;

    systemd.user.services.ydotoold = {
      Unit = {
        Description = "ydotool user input daemon";
        # Non-NixOS installs still need host-level /dev/uinput access.
        ConditionPathIsReadWrite = "/dev/uinput";
      };
      Install.WantedBy = [ "default.target" ];
      Service = {
        Type = "simple";
        ExecStartPre = "${pkgs.coreutils}/bin/rm -f ${cfg.socketPath}";
        ExecStart = "${pkgs.ydotool}/bin/ydotoold --socket-path ${cfg.socketPath} --socket-perm 0600";
        Restart = "on-failure";
        RestartSec = 2;
        TimeoutStopSec = 10;
      };
    };
  };
}
