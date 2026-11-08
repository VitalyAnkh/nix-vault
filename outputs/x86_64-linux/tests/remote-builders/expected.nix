{
  lib,
  outputs,
  ...
}:
let
  # Upstream also expects ai-niri here; eva does not build through aquamarine.
  hosts = builtins.filter (name: outputs.nixosConfigurations ? ${name}) [
    "shoryu"
    "shushou"
    "youko"
  ];
  yes = lib.genAttrs hosts (_: true);
in
{
  distributedBuilds = yes;
  aquamarineConfigured = yes;
  builderSystems = lib.genAttrs hosts (_: [ [ "x86_64-linux" ] ]);
}
