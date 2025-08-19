{
  inputs,
  lib,
  system,
  genSpecialArgs,
  home-modules,
  specialArgs ? (genSpecialArgs system),
  myvars,
  mylib,
  username ? myvars.username,
  homeDirectory ? (
    if (lib.strings.hasInfix "darwin" system) then "/Users/${username}" else "/home/${username}"
  ),
  ...
}:
let
  inherit (inputs) nixpkgs home-manager;

  # Custom overlay to add packages from pkgs/ directory
  customOverlay =
    final: prev:
    let
      sources = prev.callPackage ../pkgs/_sources/generated.nix { };
    in
    mylib.callPackageFromDirectory {
      callPackage = prev.lib.callPackageWith (prev // sources // (genSpecialArgs system));
      directory = ../pkgs;
    };

  # Determine which nixpkgs to use based on system
  pkgs =
    if (lib.strings.hasInfix "darwin" system) then
      import inputs.nixpkgs-darwin {
        inherit system;
        config.allowUnfree = true;
        overlays = [ customOverlay ];
      }
    else
      import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ customOverlay ];
      };
in
home-manager.lib.homeManagerConfiguration {
  inherit pkgs;

  extraSpecialArgs = specialArgs;

  modules = home-modules ++ [
    {
      # Basic home-manager settings
      home = {
        inherit username homeDirectory;
        stateVersion = "25.11";
      };

      # Let home-manager manage itself
      programs.home-manager.enable = true;

      # Ensure nix settings are configured
      nix = {
        package = pkgs.nix;
        settings = {
          experimental-features = [
            "nix-command"
            "flakes"
          ];
        };
      };
    }
  ];
}
