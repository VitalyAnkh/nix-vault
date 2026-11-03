{
  inputs,
  mylib,
  outputs,
  ...
}:
let
  # Upstream uses ai-niri; eva is its local successor.
  pkgs = outputs.nixosConfigurations.eva.pkgs;
in
import ../../../../hardening/tests/policy.nix {
  inherit pkgs mylib;
  mkNixPak = inputs.nixpak.lib.nixpak {
    inherit pkgs;
    inherit (pkgs) lib;
  };
}
