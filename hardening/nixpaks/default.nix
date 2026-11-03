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
  # Add nixpaked Apps into nixpkgs, and reference them in home-manager or other nixos modules.
  #
  # Firefox, QQ and Telegram keep this repository's sandbox (./modules/gui-base.nix,
  # ./modules/host-network.nix, ./modules/custom-policy.nix): host network, the
  # PipeWire socket and the cameras. WeChat uses upstream's sandbox framework
  # (./modules/wechat-policy.nix and the modules it imports). Upstream also sandboxes
  # the Chromium browsers, Blender, OBS, mpv and others; this repository does not
  # (docs/upstream-sync.md).
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
