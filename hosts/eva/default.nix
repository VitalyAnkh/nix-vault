{ myvars, lib, ... }:
#############################################################
#
# EVA - my main computer, with NixOS + 9950x + RTX 4070 Ti Super GPU, for gaming & daily use
#
#############################################################
let
  hostName = "eva"; # Define your hostname.

  inherit (myvars.networking) mainGateway mainGateway6 nameservers;
  inherit (myvars.networking.hostsAddr.${hostName}) iface ipv4 ipv6;
  ipv4WithMask = "${ipv4}/24";
  ipv6WithMask = "${ipv6}/64";
in
{
  imports = [
    ./netdev-mount.nix
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./nvidia.nix
    ./ai

    ./preservation.nix
    #./boot.nix
    #./secureboot.nix
    ./gnome.nix
  ];

  # Temporary: disable the btrbk timer on eva until we wire up a full-disk
  # backup setup that matches this host's storage layout.
  services.btrbk.instances = lib.mkForce { };

  # GDM owns eva's graphical seat. kmscon can grab KMS/DRM on tty1 during boot
  # and make GNOME Shell's greeter fail to register with GDM.
  services.kmscon.enable = lib.mkForce false;
  services.sunshine.enable = lib.mkForce true;
  services.tuned.ppdSettings.main.default = lib.mkForce "performance";

  # This host repeatedly hit swap/reclaim storms before hard resets.
  # Keep zram, but make it much less aggressive on the desktop.
  zramSwap = {
    algorithm = lib.mkForce "zstd";
    memoryPercent = lib.mkForce 50;
  };
  boot.kernel.sysctl = {
    "vm.swappiness" = lib.mkForce 100;
    "vm.watermark_scale_factor" = lib.mkForce 50;
  };

  # Let oomd watch the whole user slice, so a runaway browser session gets cut
  # before the desktop hard-stalls under RAM+zram pressure.
  systemd.oomd.enableUserSlices = lib.mkForce true;

  networking = {
    inherit hostName;

    # VR_TODO:
    # we use NetworkManager
    # how to use networkd?
    networkmanager.enable = true; # provides nmcli/nmtui for wifi adjustment
    useDHCP = lib.mkForce true;
  };

  # networking.useNetworkd = true;
  # systemd.network.enable = true;

  systemd.network.networks."10-${iface}" = {
    matchConfig.Name = [ iface ];
    networkConfig = {
      Address = [
        ipv4WithMask
        ipv6WithMask
      ];
      DNS = nameservers;
      DHCP = "ipv6"; # enable DHCPv6 only, so we can get a GUA.
      IPv6AcceptRA = true; # for Stateless IPv6 Autoconfiguraton (SLAAC)
      LinkLocalAddressing = "ipv6";
    };
    routes = [
      {
        Destination = "0.0.0.0/0";
        Gateway = mainGateway;
      }
      {
        Destination = "::/0";
        Gateway = mainGateway6;
        GatewayOnLink = true; # it's a gateway on local link.
      }
    ];
    linkConfig.RequiredForOnline = "routable";
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?
}
