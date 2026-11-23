{
  config,
  lib,
  pkgs,
  uu-remote-linux,
  ...
}:
# ===============================================================================
#
# uu-remote-linux: the unofficial Linux host for NetEase UU Remote.
#
# Upstream: https://github.com/VallierDev/uu-remote-linux (GPL-3.0, Rust, built
# from source). Its `nixosModules.default` provides `services.uu-remote-linux`
# and adds the package's overlay, so `pkgs.uu-remote-linux` exists everywhere
# this module is imported.
#
# `uuremote-native` is a systemd *user* service pulled in by
# graphical-session.target. Enabling it installs the unit but puts nothing
# online: each user must run `uuremote-server login` once and scan the QR code
# from a graphical session before their machine appears in the UU account.
#
# No inbound ports are needed. The host dials the vendor's signalling and TURN
# relays outbound, so the default-deny firewall (modules/nixos/base/networking)
# stays as it is and `openFirewall`-style options do not apply.
#
# State: everything lives in ~/.config/uuremote, persisted per host in
# hosts/eva/preservation.nix (muon reuses that list). `config.json` is 0600 and
# holds the account token *and this machine's device identity*. Never copy that
# directory to another host and never clone a host from a snapshot that carries
# it: two hosts sharing one identity keep kicking each other out of the room,
# which shows up as `Cloud room leave without peer identifier` every few
# seconds. `uuremote-server doctor` reports duplicate host instances.
#
# Runbook, including the per-user setup on muon: ./README.md
#
# ===============================================================================
let
  cfg = config.modules.desktop.uuRemote;
in
{
  imports = [
    uu-remote-linux.nixosModules.default
  ];

  options.modules.desktop.uuRemote = {
    enable = lib.mkEnableOption ''
      the unofficial NetEase UU Remote host, as the `uuremote-native` systemd
      user service
    '';

    installOnly = lib.mkEnableOption ''
      the uu-remote-linux package without registering the `uuremote-native`
      user service. For shared hosts where the tool should be available but
      nothing may start a remote-control host on its own
    '';

    uinput.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Give the active seat user access to /dev/uinput. Upstream recommends it
        for Wayland sessions: entering a password on the lock screen and the
        clipboard paste fallback for phone input methods both need it, and it
        makes key injection independent of the keyboard layout. Without it,
        GNOME Wayland still works through the xdg-desktop-portal/EIS input path
        that upstream verified.

        /dev/uinput is a seat-wide privilege: whoever holds it can inject input
        anywhere on the seat, lock and greeter screens included. As of
        2026-11-24 this option grants nothing new on eva or muon, where
        `hardware.uinput.enable` is already on through
        `modules.desktop.ydotoold`; the declaration stays explicit so the
        capability does not silently disappear if ydotoold is turned off. See
        ./README.md.
      '';
    };
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !(cfg.enable && cfg.installOnly);
          message = ''
            modules.desktop.uuRemote: `enable` and `installOnly` are mutually
            exclusive; `enable` already installs the package.
          '';
        }
      ];
    }

    (lib.mkIf cfg.enable {
      services.uu-remote-linux = {
        enable = true;
        uinput.enable = cfg.uinput.enable;
      };
    })

    # `services.uu-remote-linux` gates its whole config, uinput included, behind
    # its own `enable`, so an install-only host has to wire the package and the
    # udev rule up by hand.
    (lib.mkIf cfg.installOnly {
      environment.systemPackages = [ pkgs.uu-remote-linux ];
    })
    (lib.mkIf (cfg.installOnly && cfg.uinput.enable) {
      hardware.uinput.enable = true;
      # Ships 60-uu-remote-linux-uinput.rules, which tags /dev/uinput with
      # `uaccess` so logind grants it to the active seat user.
      services.udev.packages = [ pkgs.uu-remote-linux ];
    })
  ];
}
