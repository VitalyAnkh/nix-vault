{
  config,
  lib,
  magpie,
  pkgs,
  ...
}:
let
  cfg = config.modules.desktop.magpie;
  package = magpie.packages.${pkgs.stdenv.hostPlatform.system}.magpie;

  # What `magpie autostart on` writes to ~/.config/autostart/magpie.desktop,
  # declared instead of left to the program. Note the command: `magpie tray`
  # is the menu-bar icon alone, not the `magpie %u` of the package's own
  # desktop entry, which opens the window too. Letting magpie write the file
  # also records the path of the build it ran from, which a garbage collection
  # removes after an upgrade; this entry is rewritten by every switch and kept
  # alive by the generation that owns it.
  autostartEntry = pkgs.makeDesktopItem {
    name = "magpie";
    desktopName = "magpie";
    comment = "one place to pick every agent's model";
    exec = "${package}/bin/magpie tray";
    terminal = false;
    extraConfig."X-GNOME-Autostart-enabled" = "true";
  };

  # `magpie daemon install` bakes in the PATH of the shell it ran in, which is
  # how the gateway finds the agents' CLIs and the node its plugins start. A
  # declared unit has to spell that out: the user manager's own PATH is
  # imported from the graphical session at login, so a unit that starts before
  # that (a lingering manager at boot) would not have it. Codex is installed
  # through pnpm, hence its two directories.
  servicePath = lib.concatStringsSep ":" [
    "${config.home.homeDirectory}/.local/share/pnpm/bin"
    "${config.home.homeDirectory}/.local/share/pnpm"
    "${config.home.homeDirectory}/.local/bin"
    "${config.home.profileDirectory}/bin"
    "/run/wrappers/bin"
    "/nix/var/nix/profiles/default/bin"
    "/run/current-system/sw/bin"
  ];
in
{
  options.modules.desktop.magpie = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        magpie (github:yetone/magpie): picks which model each AI coding agent
        on this machine talks to, and runs one local gateway for all of them.
        One binary is the window, the menu-bar icon, the TUI, the web UI and
        the CLI. Installing it starts nothing and reaches nothing: the gateway
        has no models until `magpie provider add` or a subscription sign-in.
      '';
    };

    daemon.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Run the gateway as the `magpie` systemd user service, the declarative
        equivalent of `magpie daemon install`: it owns the same
        ~/.config/systemd/user/magpie.service, so do not run that command
        (it would try to overwrite a read-only store symlink).

        Off by default because the gateway binds a fixed port on loopback
        (127.0.0.1:3425), so one service per logged-in user does not work on a
        host several people share: on muon the second one would find the port
        taken. Mutually exclusive with `autostart.enable`, which upstream
        refuses for the same reason.

        The service only serves the gateway; opening the app by hand gives the
        window and reuses this gateway. Without
        `users.users.<name>.linger = true` on the host, systemd starts it at
        the user's first login, not at boot.
      '';
    };

    autostart.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Start `magpie tray` at login through ~/.config/autostart, the
        declarative equivalent of `magpie autostart on`. The app serves the
        gateway itself, so this is mutually exclusive with `daemon.enable`.

        Off by default because GNOME has no tray on these hosts, which would
        leave an invisible process: use `daemon.enable` and open the window
        from the app grid when it is wanted. Worth turning on for a session
        that does show a tray (niri with Noctalia).
      '';
    };
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !(cfg.daemon.enable && cfg.autostart.enable);
          message = ''
            modules.desktop.magpie: daemon.enable and autostart.enable are
            mutually exclusive. Both serve the gateway, so they would take
            turns failing on 127.0.0.1:3425; upstream's own `daemon install`
            refuses to run while autostart is on.
          '';
        }
        {
          assertion = (cfg.daemon.enable || cfg.autostart.enable) -> cfg.enable;
          message = ''
            modules.desktop.magpie: daemon.enable or autostart.enable needs
            enable = true, which installs the package they run.
          '';
        }
      ];
    }

    (lib.mkIf (cfg.enable && pkgs.stdenv.hostPlatform.isLinux) {
      home.packages = [ package ];

      # magpie otherwise sends one event a day: an install id, its version,
      # and the ids of the agents, providers and models in use. Same opt-out
      # as the other agents keep in home/base/tui/agents/env.nix, but set for
      # the systemd user manager as well, because magpie is started from the
      # desktop or by a user unit rather than from a login shell.
      home.sessionVariables.MAGPIE_NO_STATS = "1";
      systemd.user.sessionVariables.MAGPIE_NO_STATS = "1";
    })

    (lib.mkIf (cfg.enable && cfg.daemon.enable && pkgs.stdenv.hostPlatform.isLinux) {
      # Mirrors the unit `magpie daemon install` writes. Upstream makes that
      # file readable by its owner alone, because the environment it captures
      # can carry a proxy password; a unit in the store is world-readable, so
      # keep credentials out of Environment= here and let magpie read them
      # from its own 0600 files under ~/.config/magpie.
      systemd.user.services.magpie = {
        Unit = {
          Description = "magpie gateway";
          After = [ "network-online.target" ];
        };
        Install.WantedBy = [ "default.target" ];
        Service = {
          Type = "simple";
          ExecStart = "${package}/bin/magpie serve";
          Environment = [ "PATH=${servicePath}" ];
          # Upstream restarts the gateway when it stops with a failure, and
          # leaves a deliberate `systemctl --user stop magpie` alone.
          Restart = "on-failure";
          RestartSec = 5;
        };
      };
    })

    (lib.mkIf (cfg.enable && cfg.autostart.enable && pkgs.stdenv.hostPlatform.isLinux) {
      xdg.autostart.entries = [
        "${autostartEntry}/share/applications/magpie.desktop"
      ];
    })
  ];
}
