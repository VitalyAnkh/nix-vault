{
  description = "NixOS configuration of VitalyR";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    preservation.url = "github:nix-community/preservation";
    nuenv.url = "github:DeterminateSystems/nuenv";

    nixos-apple-silicon = {
      url = "github:nix-community/nixos-apple-silicon/release-2025-05-30";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # my-asahi-firmware = {
    #   url = "git+ssh://git@github.com/ryan4yin/asahi-firmware.git?shallow=1";
    #   flake = false;
    # };
  };

  outputs =
    inputs@{
      nixpkgs,
      nixos-apple-silicon,
      # my-asahi-firmware,
      ...
    }:
    let
      inherit (inputs.nixpkgs) lib;
      mylib = import ../lib { inherit lib; };
      myvars = import ../vars { inherit lib; };
    in
    {
      nixosConfigurations = {
        ai = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = inputs // {
            inherit mylib myvars;
          };

          modules = [
            { networking.hostName = "eva"; }

            ./configuration.nix

            ../modules/base
            ../modules/nixos/base/i18n.nix
            ../modules/nixos/base/user-group.nix
            ../modules/nixos/base/ssh.nix

            ../hosts/eva/hardware-configuration.nix
            ../hosts/eva/preservation.nix
          ];
        };

        shoukei = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = inputs // {
            inherit mylib myvars my-asahi-firmware;
          };
          modules = [
            { networking.hostName = "shoukei"; }

            nixos-apple-silicon.nixosModules.default
            ./configuration.nix

            ../modules/base
            ../modules/nixos/base/i18n.nix
            ../modules/nixos/base/user-group.nix
            ../modules/nixos/base/ssh.nix

            ../hosts/12kingdoms-shoukei/hardware-configuration.nix
            ../hosts/eva/impermanence.nix
            ../hosts/eva/preservation.nix
          ];
        };
      };
    };
}
