{
  config,
  lib,
  pkgs,
  nixpkgs-zotero,
  ...
}:
let
  supported = pkgs.stdenv.isDarwin || pkgs.stdenv.isx86_64;
  # nixpkgs unstable builds Zotero 10 on Firefox ESR 153, but Zotero 10 targets
  # ESR 140: its build removes the AboutTranslations actor, which ESR 153.4 no
  # longer has, so the build fails and the cache has none. Take the cached
  # Zotero 10.0.2 from the pinned nixpkgs-zotero input (flake.nix) instead; a
  # Zotero older than the one that last opened ~/Zotero cannot open it.
  zotero = nixpkgs-zotero.legacyPackages.${pkgs.stdenv.hostPlatform.system}.zotero;
in
{
  options.modules.desktop.academia.enable = lib.mkEnableOption "Zotero and Obsidian" // {
    default = true;
  };

  config = lib.mkIf (supported && config.modules.desktop.academia.enable) {
    home.packages = [
      zotero
      pkgs.obsidian
    ];
  };
}
