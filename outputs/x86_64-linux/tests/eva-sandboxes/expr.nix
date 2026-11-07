# This repository's own nixpak modules (Firefox, QQ, Telegram), which the
# nixpak-policy suite does not describe (hardening/tests/policy-lib.nix).
{
  inputs,
  outputs,
  ...
}:
let
  host = outputs.nixosConfigurations.eva;
  inherit (host) pkgs;
  inherit (pkgs) lib;
  mkNixPak = inputs.nixpak.lib.nixpak {
    inherit pkgs lib;
  };
  load =
    name:
    (pkgs.callPackage (../../../../hardening/nixpaks + "/${name}.nix") { inherit mkNixPak; }).config;
  firefox = load "firefox";
  qq = load "qq";
  telegram = load "telegram-desktop";
  hasFido = app: lib.elem "/dev/fido-hidraw" app.bubblewrap.bind.dev;
  usesFidoWrapper = app: lib.getName app.bubblewrap.package == "bwrap";
  roStrings = app: builtins.filter builtins.isString (lib.flatten app.bubblewrap.bind.ro);
in
{
  # FIDO2: only the FIDO hidraw nodes reach Firefox, through the udev-maintained
  # directory and the wrapper that links /dev/hidrawN into it.
  hostLinksFidoNodes = lib.hasInfix "/dev/fido-hidraw/%k" host.config.services.udev.extraRules;
  fidoDirAtBoot = lib.elem "d /dev/fido-hidraw 0755 root root -" host.config.systemd.tmpfiles.rules;
  firefoxFido = hasFido firefox && usesFidoWrapper firefox;
  firefoxNoBroadUdev = !lib.any (path: path == "/sys" || path == "/run/udev") (roStrings firefox);
  othersNoFido =
    !lib.any (app: hasFido app || usesFidoWrapper app) [
      qq
      telegram
    ];

  # QQ copies through the X11 clipboard; its /tmp is a per-app directory so the
  # X11 socket bind is not hidden by a tmpfs. The other apps stay Wayland-only.
  qqX11 = qq.bubblewrap.sockets.x11 && !lib.elem "/tmp" qq.bubblewrap.tmpfs;
  telegramWaylandOnly = !telegram.bubblewrap.sockets.x11 && lib.elem "/tmp" telegram.bubblewrap.tmpfs;
  firefoxWaylandOnly = !firefox.bubblewrap.sockets.x11 && lib.elem "/tmp" firefox.bubblewrap.tmpfs;
}
