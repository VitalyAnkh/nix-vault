{
  lib,
  outputs,
  ...
}:
let
  yes = lib.genAttrs (builtins.filter (name: outputs.nixosConfigurations ? ${name}) [
    "shoryu"
    "shushou"
    "youko"
  ]) (_: true);
in
{
  distributedBuilds = yes;
  aquamarineConfigured = yes;
}
