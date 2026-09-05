{
  myvars,
  outputs,
  ...
}:
let
  userGroups = outputs.nixosConfigurations.eva.config.users.users.${myvars.username}.extraGroups;
in
{
  userHasDockerAccess = builtins.elem "docker" userGroups;
  userHasPodmanAccess = builtins.elem "podman" userGroups;
}
