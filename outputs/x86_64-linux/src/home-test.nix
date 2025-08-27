{
  inputs,
  lib,
  myvars,
  mylib,
  system,
  genSpecialArgs,
  ...
}@args:
{
  homeConfigurations = {
    "test-config" = inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      modules = [
        {
          home = {
            username = myvars.username;
            homeDirectory = "/home/${myvars.username}";
            stateVersion = "24.11";
          };
          programs.home-manager.enable = true;
        }
      ];
    };
  };
}
