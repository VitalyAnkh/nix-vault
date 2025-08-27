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
  home_manager_config = import ./home-manager.nix args;
  inherit (home_manager_config) linux_gui_home_modules mkHomeConfig;
in
{
  # Standalone home-manager configurations for non-NixOS system
  homeConfigurations = {
    # Full configuration with all Linux modules including GUI
    "${name}" = mkHomeConfig {
      modules = linux_gui_home_modules ++ [
        # host specific configuration
        (mylib.relativeToRoot "hosts/${name}/home.nix")
      ];
    };
  };
}
