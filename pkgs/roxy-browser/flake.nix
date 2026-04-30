{
  description = "Roxy Browser binary package";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      roxy-browser = pkgs.callPackage ./package.nix { };
    in
    {
      packages.${system} = {
        default = roxy-browser;
        inherit roxy-browser;
      };

      apps.${system} = {
        default = {
          type = "app";
          program = "${roxy-browser}/bin/roxy-browser";
        };
        roxy-browser = {
          type = "app";
          program = "${roxy-browser}/bin/roxy-browser";
        };
      };
    };
}
