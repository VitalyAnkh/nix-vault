{
  myvars,
  lib,
  outputs,
}:
let
  username = myvars.username;
  hosts = [
    "eva"
    "aquamarine"
    "ruby"
  ];
in
lib.genAttrs hosts (name: {
  inherit (outputs.nixosConfigurations.${name}.config.home-manager.users.${username}.xdg)
    enable
    stateHome
    ;
})
