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
  # Define common home-manager modules for Darwin systems
  base-home-modules = map mylib.relativeToRoot [
    "home/base/core"
    "home/base/tui"
    "home/darwin"
  ];

  # Create configurations for Darwin
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
  homeConfigurations = {
    # Configuration for macOS systems
    "${myvars.username}@aarch64-darwin" = mkHomeConfig {
      modules = base-home-modules;
    };
  };
}
