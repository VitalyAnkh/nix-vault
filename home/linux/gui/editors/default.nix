{ mylib, pkgs-unstable, ... }:
{
  home.packages = with pkgs-unstable; [
    # zed-editor
    # code-cursor
  ];
  imports = mylib.scanPaths ./.;
}
