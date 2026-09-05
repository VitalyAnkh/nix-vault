{
  lib,
  outputs,
}:
let
  desktopHosts = [
    "shoukei-niri"
    "eva"
    "eva-niri"
    "muon"
  ];
in
lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (
  name: builtins.elem name desktopHosts
)
