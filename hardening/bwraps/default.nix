{
  nixpkgs.overlays = [
    (_: super: {
      # bwrap-based hardened apps are Linux-only; keep attrset defined on
      # other platforms but avoid evaluating Linux-only packages.
      bwraps =
        if super.stdenv.hostPlatform.isLinux then
          {
            wechat = super.callPackage ./wechat.nix { };
          }
        else
          { };
    })
  ];
}
