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
  inherit (home-manager-config) base-home-modules gui-home-modules mkHomeConfig;

  # Base modules for TUI-only setup (servers, minimal systems)
  tui-modules = {
    home-modules = base-home-modules ++ [
      # host specific configuration
      (mylib.relativeToRoot "hosts/${name}/home.nix")
    ];
  };

  # Full desktop modules with GUI support
  desktop-modules = {
    home-modules =
      tui-modules.home-modules
      ++ gui-home-modules
      ++ [
        # Enable desktop features for this host
        {
          modules.desktop.hyprland.enable = true;
          modules.desktop.fonts.enable = true;
          modules.desktop.wayland.enable = true;
          modules.editors.emacs.enable = false; # Can be enabled if needed
        }
      ];
  };
in
{
  # Standalone home-manager configurations for non-NixOS system
  homeConfigurations = {
    # TUI-only configuration for servers or resource-constrained systems
    "${name}" = mkHomeConfig {
      modules = tui-modules.home-modules;
    };

    # Full desktop configuration with GUI for capable hardware
    "${name}-desktop" = mkHomeConfig {
      modules = desktop-modules.home-modules;
    };
  };
}
