{ lib, outputs }:
let
  baseline = {
    userHasDockerAccess = false;
    userHasPodmanAccess = false;
    userHasDiskAccess = false;
    userHasKvmAccess = false;
    userHasInputAccess = false;
  };

  # MUON intentionally keeps its multi-user container workflow: the rootful
  # Docker daemon shares images between its users (hosts/muon/docker.nix).
  # Podman is off there, so the podman group grants nothing.
  muon = baseline // {
    userHasDockerAccess = true;
    userHasPodmanAccess = true;
  };
in
lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (
  name: if lib.hasPrefix "muon" name then muon else baseline
)
