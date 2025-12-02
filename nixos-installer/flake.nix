{
  description = "NixOS configuration of VitalyR";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    preservation.url = "github:nix-community/preservation";
    nuenv.url = "github:DeterminateSystems/nuenv";

    nixos-apple-silicon = {
      # 2025-10-07 asahi-6.16.8-1
      url = "github:nix-community/nixos-apple-silicon/24ab28e47b586f741910b3a2f0428f3523a0fff3";
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
        eva = nixpkgs.lib.nixosSystem {
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

        muon = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = inputs // {
            inherit mylib myvars;
          };

          modules = [
            { networking.hostName = "muon"; }

            ./configuration.nix

            ../modules/base
            ../modules/nixos/base/i18n.nix
            ../modules/nixos/base/user-group.nix
            ../modules/nixos/base/ssh.nix

            ../hosts/muon/hardware-configuration.nix
            ../hosts/eva/preservation.nix
            ../hosts/muon/preservation-users.nix
          ];
        };

        shoukei = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = inputs // {
            # inherit mylib myvars my-asahi-firmware;
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
            # VR_TODO:
            ../hosts/eva/preservation.nix
          ];
        };
      };
    };
}
