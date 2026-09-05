{
  lib,
  outputs,
}:
lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (
  name:
  let
    isK3s = lib.hasPrefix "k3s" name;
    extraFlags = outputs.nixosConfigurations.${name}.config.services.k3s.extraFlags or [ ];
    flags =
      if !isK3s then
        ""
      else if builtins.isList extraFlags then
        lib.concatStringsSep " " extraFlags
      else
        extraFlags;
  in
  {
    mode600 = lib.hasInfix "--write-kubeconfig-mode=600" flags;
    mode644 = lib.hasInfix "--write-kubeconfig-mode=644" flags;
  }
)
