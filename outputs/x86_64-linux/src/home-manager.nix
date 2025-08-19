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
  # Define common home-manager modules for Linux systems
  base-home-modules = map mylib.relativeToRoot [
    "home/base/core"
    "home/base/tui"
    "home/linux/base"
  ];

  # GUI modules for desktop environments
  gui-home-modules = map mylib.relativeToRoot [
    "home/linux/gui.nix"
  ];

  # Create configurations for different setups
  mkHomeConfig =
    {
      modules,
      username ? myvars.username,
    }:
    mylib.homeManagerConfiguration (
      args
      // {
        inherit system username;
        home-modules = modules;
      }
    );
in
{
  # Export these for reuse in other files like revachol.nix
  inherit base-home-modules gui-home-modules mkHomeConfig;

  homeConfigurations = {
    # Basic TUI configuration for servers or minimal systems
    "${myvars.username}@x86_64-linux" = mkHomeConfig {
      modules = base-home-modules;
    };

    # Full desktop configuration for desktop systems
    "${myvars.username}-desktop@x86_64-linux" = mkHomeConfig {
      modules = base-home-modules ++ gui-home-modules;
    };
  };
}
