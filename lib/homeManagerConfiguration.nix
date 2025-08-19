{
  inputs,
  lib,
  system,
  genSpecialArgs,
  home-modules,
  specialArgs ? (genSpecialArgs system),
  myvars,
  username ? myvars.username,
  homeDirectory ? (
    if (lib.strings.hasInfix "darwin" system) then "/Users/${username}" else "/home/${username}"
  ),
  ...
}:
let
  inherit (inputs) nixpkgs home-manager;

  # Determine which nixpkgs to use based on system
  pkgs =
    if (lib.strings.hasInfix "darwin" system) then
      import inputs.nixpkgs-darwin {
        inherit system;
        config.allowUnfree = true;
      }
    else
      import nixpkgs {
        inherit system;
        config.allowUnfree = true;
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
        stateVersion = "24.11";
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
