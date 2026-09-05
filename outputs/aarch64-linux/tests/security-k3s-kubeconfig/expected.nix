{
  lib,
  outputs,
}:
lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (
  name:
  let
    enabled = outputs.nixosConfigurations.${name}.config.services.k3s.enable;
  in
  {
    # Only enabled control-plane (master) nodes write the admin kubeconfig.
    # Local eval without age tokens leaves k3s disabled, so the flag is absent.
    mode600 = enabled && lib.hasInfix "-master-" name;
    mode644 = false;
  }
)
