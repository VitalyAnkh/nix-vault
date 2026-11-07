{
  pkgs,
  pkgs-master,
  nixpak,
  firefox,
  ...
}:
let
  callArgs = {
    inherit pkgs firefox;
    mkNixPak = nixpak.lib.nixpak {
      inherit (pkgs) lib;
      inherit pkgs;
    };
  };
  wrapper = _pkgs: path: (_pkgs.callPackage path callArgs);
in
{
  # FIDO2 hotplug for the sandboxed Firefox (see modules/fido-bwrap.nix). The
  # directory is created at boot, before udevd starts, so the browser bind
  # succeeds even with no key present. NixOS applies /dev tmpfiles entries only
  # at boot; for a first deploy via switch, see hardening/README.md (Limits).
  # Hard links share the device inode, so logind's uaccess ACLs stay
  # authoritative, and removal on unplug leaves no stale node for a reused
  # hidraw minor. 60-fido-id.rules sets ID_FIDO_TOKEN from the report
  # descriptor, so a key's keyboard interface is never linked. Upstream also
  # links joysticks into /dev/gamepad-input for its game sandboxes, which this
  # repository does not use.
  systemd.tmpfiles.rules = [ "d /dev/fido-hidraw 0755 root root -" ];
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="hidraw", ENV{ID_FIDO_TOKEN}=="1", RUN+="${pkgs.coreutils}/bin/ln -f /dev/%k /dev/fido-hidraw/%k"
    ACTION=="remove", SUBSYSTEM=="hidraw", RUN+="${pkgs.coreutils}/bin/rm -f /dev/fido-hidraw/%k"
  '';

  # Add nixpaked Apps into nixpkgs, and reference them in home-manager or other nixos modules.
  #
  # Firefox, QQ and Telegram keep this repository's sandbox (./modules/gui-base.nix,
  # ./modules/host-network.nix, ./modules/custom-policy.nix): host network, the
  # PipeWire socket and the cameras. WeChat uses upstream's sandbox framework
  # (./modules/wechat-policy.nix and the modules it imports). Upstream also sandboxes
  # the Chromium browsers, Blender, OBS, mpv, Steam, Heroic, umu and others; this
  # repository does not (docs/upstream-sync.md).
  nixpkgs.overlays = [
    (_: super: {
      nixpaks = {
        qq = wrapper pkgs-master ./qq.nix;
        telegram-desktop = wrapper super ./telegram-desktop.nix;
        firefox = wrapper super ./firefox.nix;
        wechat = wrapper pkgs-master ./wechat.nix;
      };
    })
  ];
}
