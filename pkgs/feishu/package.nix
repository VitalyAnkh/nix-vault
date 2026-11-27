{
  lib,
  stdenv,
  feishu,
  source-feishu,
}:
let
  # nixpkgs' installPhase wraps the main binary and the built-in vulcan
  # browser; the deb dropped vulcan/ by 7.72.23, so wrapping it would fail.
  wrappedExecutables = "{feishu,vulcan/vulcan}";
in
# nixpkgs' feishu repackages the official .deb but is rarely updated (7.66.11
# since 2026-08), so on x86_64-linux take the current official release that
# nvfetcher tracks; the build steps stay nixpkgs'. Other platforms keep
# nixpkgs' release.
if stdenv.hostPlatform.system == "x86_64-linux" then
  feishu.overrideAttrs (old: {
    # nvfetcher's version is the download path, "<dir>/Feishu-linux_x64-<version>".
    version = lib.removePrefix "Feishu-linux_x64-" (
      lib.last (lib.splitString "/" source-feishu.version)
    );
    inherit (source-feishu) src;
    installPhase =
      if lib.hasInfix wrappedExecutables old.installPhase then
        builtins.replaceStrings [ wrappedExecutables ] [ "feishu" ] old.installPhase
      else
        throw "pkgs/feishu: nixpkgs' feishu installPhase no longer wraps ${wrappedExecutables}; review this override";
  })
else
  feishu
