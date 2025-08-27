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
  # Base modules - cross-platform, no GUI
  base_home_modules = map mylib.relativeToRoot [
    "home/base/core"
    "home/base/tui"
  ];

  # GUI modules - cross-platform GUI
  gui_home_modules = map mylib.relativeToRoot [
    "home/base/gui"
  ];

  # Linux complete modules - all Linux modules including GUI and TUI
  linux_gui_home_modules = map mylib.relativeToRoot [
    "home/linux/gui.nix"  # This already imports all base modules
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
  inherit base_home_modules gui_home_modules linux_gui_home_modules mkHomeConfig;

  homeConfigurations = {
    # Basic TUI configuration for servers or minimal systems
    "${myvars.username}@x86_64-linux" = mkHomeConfig {
      modules = base_home_modules ++ [ (mylib.relativeToRoot "home/linux/base") ];
    };

    # Full desktop configuration for desktop systems
    "${myvars.username}-desktop@x86_64-linux" = mkHomeConfig {
      modules = linux_gui_home_modules;
    };
  };
}
