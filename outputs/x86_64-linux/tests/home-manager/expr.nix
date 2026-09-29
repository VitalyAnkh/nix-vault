{
  myvars,
  lib,
  outputs,
}:
let
  username = myvars.username;
  hosts = [
    "eva"
    "muon"
    "ruby"
  ];
in
lib.genAttrs hosts (
  name: outputs.nixosConfigurations.${name}.config.home-manager.users.${username}.home.homeDirectory
)
