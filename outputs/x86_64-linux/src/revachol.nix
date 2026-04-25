{
  inputs,
  lib,
  myvars,
  mylib,
  system,
  genSpecialArgs,
  ...
}@args:
let
  name = "revachol"; # Non-NixOS host for standalone home-manager

  # Import common configurations from home-manager.nix
  home-manager-config = import ./home-manager.nix args;
  inherit (home-manager-config) mkHomeConfig;
in
{
  # Standalone home-manager configurations for non-NixOS system
  homeConfigurations = {
    # Full configuration with all Linux modules including GUI
    "${name}" = mkHomeConfig {
      modules = [ (mylib.relativeToRoot "home/hosts/linux/${name}.nix") ];
    };
  };
}
