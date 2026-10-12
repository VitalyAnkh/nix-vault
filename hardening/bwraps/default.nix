{ pkgs-master, ... }:
{
  nixpkgs.overlays = [
    (_: super: {
      # bwrap-based hardened apps are Linux-only; keep attrset defined on
      # other platforms but avoid evaluating Linux-only packages.
      bwraps =
        if super.stdenv.hostPlatform.isLinux then
          {
            # Track WeChat from nixpkgs-master, which carries the newest builds.
            wechat = super.callPackage ./wechat.nix { wechat = pkgs-master.wechat; };
          }
        else
          { };
    })
  ];
}
