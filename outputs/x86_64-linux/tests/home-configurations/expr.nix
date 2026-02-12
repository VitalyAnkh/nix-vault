{
  lib,
  myvars,
  outputs,
}:
let
  username = myvars.username;
  hosts = [
    "revachol"
    "jojo"
  ];
in
lib.genAttrs hosts (name: {
  inherit username;
  homeDirectory = outputs.homeConfigurations.${name}.config.home.homeDirectory;
  actualUsername = outputs.homeConfigurations.${name}.config.home.username;
})
