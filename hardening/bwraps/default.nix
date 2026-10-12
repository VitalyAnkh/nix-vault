{ pkgs-master, ... }:
{
  nixpkgs.overlays = [
    (_: super: {
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
