{ lib, pkgs, ... }:
let
  supported = pkgs.stdenv.isDarwin || pkgs.stdenv.isx86_64;
in
{
  home.packages = lib.optionals supported (
    with pkgs;
    [
      zotero
      obsidian
    ]
  );
}
