{myvars, ...}:
#############################################################
#
# EVA - my main computer, with NixOS + 9950x + RTX 4090 GPU, for gaming & daily use
#
#############################################################
let
  hostName = "eva"; # Define your hostname.
in {
  imports = [
    ./netdev-mount.nix
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./nvidia.nix

    ./impermanence.nix
    #./boot.nix
    #./secureboot.nix
  ];

  boot.loader.systemd-boot.enable = true;

  networking = {
    inherit hostName;
    inherit (myvars.networking) defaultGateway nameservers;
    inherit (myvars.networking.hostsInterface.${hostName}) interfaces;

    # desktop need its cli for status bar
    networkmanager.enable = true;
  };

  # conflict with feature: containerd-snapshotter
  # virtualisation.docker.storageDriver = "btrfs";

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
