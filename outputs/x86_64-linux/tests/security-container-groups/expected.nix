{ lib, outputs }:
let
  baseline = {
    userHasDockerAccess = false;
    userHasPodmanAccess = false;
    userHasDiskAccess = false;
    userHasKvmAccess = false;
    userHasInputAccess = false;
  };

  # MUON intentionally keeps its multi-user container workflow. The local
  # role is rootful Podman/docker-compatible access, unlike the desktop hosts.
  muon = baseline // {
    userHasDockerAccess = true;
    userHasPodmanAccess = true;
  };
in
lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (
  name: if lib.hasPrefix "muon" name then muon else baseline
)
