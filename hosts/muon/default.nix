{ myvars, lib, ... }:
#############################################################
#
# Muon - NixOS + 3700x + RTX 5070 Ti Super GPU
#
#############################################################
let
  hostName = "muon"; # Define your hostname.

  inherit (myvars.networking) defaultGateway defaultGateway6 nameservers;
  inherit (myvars.networking.hostsAddr.${hostName}) iface ipv4 ipv6;
  ipv4WithMask = "${ipv4}/23";
  ipv6WithMask = "${ipv6}/64";

  serviceConfigNoMountNamespace = {
    PrivateTmp = lib.mkForce "no";
    ProtectSystem = lib.mkForce "no";
    ProtectHome = lib.mkForce "no";
  };

  serviceConfigNoMountNamespaceWithDevices = serviceConfigNoMountNamespace // {
    PrivateDevices = lib.mkForce "no";
  };
in
{
  imports = [
    ./netdev-mount.nix
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./nvidia.nix
    ./users.nix # Multi-user configuration for muon machine
    ./xremap.nix # xremap for vitalyr only

    # Use eva's preservation configuration for muon as well
    ../eva/preservation.nix
    ./preservation-users.nix
    #./boot.nix
    #./secureboot.nix
    ./gnome.nix
    ./docker.nix # Use real Docker instead of Podman for this host
  ];

  # Disable the global user-group.nix module since we have our own users.nix
  disabledModules = [
    "../../modules/nixos/base/user-group.nix"
  ];

  # GDM owns muon's graphical seat. kmscon can grab KMS/DRM on tty1 during boot
  # and make GNOME Shell's greeter fail to register with GDM.
  services.kmscon.enable = lib.mkForce false;

  boot.loader.systemd-boot.enable = true;

  zramSwap.memoryPercent = lib.mkForce 10;

  # Enable SSH password authentication for this host
  services.openssh.settings.PasswordAuthentication = lib.mkForce true;
  # ModemManager times out on this host and makes `nixos-rebuild switch` fail.
  # Disable it unless cellular modem support is needed.
  networking.modemmanager.enable = false;
  # On muon we have a very large number of bind mounts from preservation.
  # systemd's hardening options like `ProtectSystem=strict`/`ProtectHome=yes`/`PrivateTmp=yes`
  # require a private mount namespace; with thousands of mounts, systemd-executor can time out
  # while setting it up, breaking `systemd-logind`/`polkit`/`systemd-hostnamed` and thus GNOME
  # and `nixos-rebuild switch`.
  #
  # Relax these services to avoid mount-namespace setup.
  systemd.services = {
    # Avoid polkit restart timeouts during `nixos-rebuild switch`.
    polkit = {
      restartIfChanged = false;
      serviceConfig = serviceConfigNoMountNamespaceWithDevices;
    };

    systemd-logind.serviceConfig = serviceConfigNoMountNamespace;
    systemd-hostnamed.serviceConfig = serviceConfigNoMountNamespace;

    netbird-homelab = {
      serviceConfig = serviceConfigNoMountNamespaceWithDevices;
      wantedBy = lib.mkForce [ ];
    };
    avahi-daemon.serviceConfig = serviceConfigNoMountNamespaceWithDevices;

    # netbird-homelab start-pre can time out on this host (a lot of preservation bind mounts),
    # and when it's started synchronously from multi-user/graphical targets it can block boot
    # and even make `nixos-rebuild switch` fail.
    #
    # Keep the client unit installed but not in the critical boot chain; start it asynchronously.
    netbird-homelab-autostart = {
      description = "Async start netbird-homelab after boot";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "/run/current-system/sw/bin/systemctl start --no-block netbird-homelab.service";
      };
    };
  };
  services.netbird.clients.homelab.autoStart = lib.mkForce false;

  networking = {
    inherit hostName;

    # VR_TODO:
    # we use NetworkManager
    # how to use networkd?
    networkmanager.enable = true; # provides nmcli/nmtui for wifi adjustment
    # Let NetworkManager handle DHCP; disable dhcpcd to avoid start timeouts.
    useDHCP = lib.mkForce false;
    dhcpcd.enable = false;
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
        Gateway = defaultGateway;
      }
      {
        Destination = "::/0";
        Gateway = defaultGateway6;
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
  system.stateVersion = "25.05"; # Did you read the comment?
}
