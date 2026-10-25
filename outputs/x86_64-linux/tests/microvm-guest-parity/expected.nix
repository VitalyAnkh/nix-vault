{
  lib,
  outputs,
}:
let
  # youko is absent without the private secrets input (12kingdoms-youko.nix).
  vmHosts = builtins.filter (host: outputs.nixosConfigurations ? ${host}) [
    "shoryu"
    "shushou"
    "youko"
  ];
in
lib.mergeAttrsList (
  map (
    host:
    lib.mapAttrs' (
      guest: _: lib.nameValuePair "${host}/${guest}" guest
    ) outputs.nixosConfigurations.${host}.config.microvm.vms
  ) vmHosts
)
