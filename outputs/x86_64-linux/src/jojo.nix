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
  name = "jojo"; # Low-spec cloud host for minimal setup

  # Import common configurations from home-manager.nix
  home-manager-config = import ./home-manager.nix args;
  inherit (home-manager-config) base-home-modules mkHomeConfig;

  # Minimal modules for low-spec cloud host (TUI only, no GUI)
  minimal-modules = {
    home-modules = base-home-modules ++ [
      # host specific configuration
      (mylib.relativeToRoot "hosts/${name}/home.nix")
      # No GUI modules - just use base TUI configuration
    ];
  };
in
{
  # Standalone home-manager configuration for low-spec cloud host
  homeConfigurations = {
    # Minimal configuration optimized for 1 core CPU, 2GB RAM, 20GB storage
    "${name}" = mkHomeConfig {
      modules = minimal-modules.home-modules;
    };
  };
}