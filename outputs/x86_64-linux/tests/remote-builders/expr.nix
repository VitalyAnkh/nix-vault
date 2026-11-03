{
  lib,
  outputs,
  ...
}:
let
  # Upstream also lists ai-niri; eva does not build through aquamarine. youko is
  # absent without the private secrets input.
  builderHosts = builtins.filter (name: outputs.nixosConfigurations ? ${name}) [
    "shoryu"
    "shushou"
    "youko"
  ];
  cfg = name: outputs.nixosConfigurations.${name}.config;
  usesAquamarine =
    name:
    builtins.any (machine: machine.hostName == "aquamarine" && machine.sshUser == "root")
      (cfg name).nix.buildMachines;
in
{
  distributedBuilds = lib.genAttrs builderHosts (name: (cfg name).nix.distributedBuilds);
  aquamarineConfigured = lib.genAttrs builderHosts usesAquamarine;
}
