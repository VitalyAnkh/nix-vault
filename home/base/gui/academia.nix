{
  config,
  lib,
  pkgs,
  ...
}:
let
  supported = pkgs.stdenv.isDarwin || pkgs.stdenv.isx86_64;
in
{
  options.modules.desktop.academia.enable = lib.mkEnableOption "Zotero and Obsidian" // {
    default = true;
  };

  config = lib.mkIf (supported && config.modules.desktop.academia.enable) {
    home.packages = [
      pkgs.zotero
      pkgs.obsidian
    ];
  };
}
