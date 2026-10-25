{
  myvars,
  lib,
  pkgs,
  disko,
  ...
}:
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
    disko.nixosModules.default
    ./disko-fs.nix
    ./nvidia.nix
    ./nvidia-niri.nix
    ./ai

    ./preservation.nix
    ./proxy.nix
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

  # Monitor SSD/NVMe SMART attributes so a failing drive shows up before it
  # dies (upstream idols-ai, dc3ec8c1). smartd autodetects devices and reports
  # to the journal; mail notifications stay off without an MTA.
  services.smartd.enable = true;

  # Scrub the btrfs disk monthly. A scrub reads every block back and checks its
  # checksum, so damage shows up even in files nothing reads: a manual scrub in
  # 2026-10 found two files that had been corrupt since 2025-12. All subvolumes
  # live on one filesystem and a scrub always covers the whole filesystem, so a
  # single mount point is enough.
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/nix" ];
  };

  # Upstream runs these exporters bound to the static LAN IPv4 in
  # vars/networking.nix, for the VictoriaMetrics instance on youko. Nothing
  # scrapes this host: its address comes from NetworkManager (DHCP, Wi-Fi on
  # eva) and is not that one, and the firewall admits only youko to the ports.
  services.prometheus.exporters.node.enable = lib.mkForce false;
  services.prometheus.exporters.smartctl.enable = lib.mkForce false;
  # monitoring.nix still orders both units after network-online.target, which
  # without the exporters leaves units with no command; mask them instead.
  systemd.services.prometheus-node-exporter.enable = false;
  systemd.services.prometheus-smartctl-exporter.enable = false;

  # Allow SSH password authentication on eva.
  # Keep root usable for remote deployment; do not inherit desktop PermitRootLogin = no.
  services.openssh.settings = {
    PasswordAuthentication = lib.mkForce true;
    PermitRootLogin = lib.mkForce "prohibit-password";
  };

  services.sunshine.enable = lib.mkForce true;

  # External monitors answer DDC/CI on /dev/i2c-*: this loads i2c-dev and installs
  # udev rules that grant the i2c group and locally logged-in users access, so
  # `ddcutil` sets brightness or the input source without sudo (upstream ai).
  environment.systemPackages = [ pkgs.ddcutil ];
  hardware.i2c.enable = true;

  # The board's ARGB controller is Gigabyte RGB Fusion, a USB HID device (ITE
  # 048d:5711). This installs openrgb with its udev rules and runs `openrgb
  # --server`, so the GUI and the CLI reach the board without root. `motherboard`
  # follows hardware.cpu.amd.updateMicrocode, which loads i2c-piix4 for the SMBus.
  services.hardware.openrgb.enable = true;

  # Keep the NVIDIA root port out of PCIe power-saving paths. Repeated Xid 79
  # freezes showed the GPU disappearing from the PCIe bus, and live sampling
  # previously showed corrected TLP errors before failure.
  boot.kernelParams = [
    "pcie_aspm=off"
    "pcie_port_pm=off"
  ];

  # The mounts come from hardware-configuration.nix; disko-fs.nix describes the
  # same disk for a reinstall only.
  disko.enableConfig = false;

  # Memory: upstream ai's scheme. zram keeps its compressed pages in RAM and can
  # deadlock as memory runs out; this host hit swap/reclaim storms before hard
  # resets even with a less aggressive zram (zstd, half the RAM, swappiness
  # 100). Swap goes to the 64 GiB swapfile on the @swap subvolume instead
  # (mounted at /swap, see hardware-configuration.nix), with zswap as a
  # compressed cache in front of it. Disabling the zram module also drops its
  # swappiness=180 tuning.
  modules.zram.enable = false;
  boot.zswap = {
    enable = true;
    compressor = "zstd";
    # 10% of RAM, as upstream: a larger pool competes with the page cache.
    maxPoolPercent = 10;
  };
  swapDevices = [ { device = "/swap/swapfile"; } ];

  # Reclaim policy from upstream ai, which uses the same swapfile plus zswap.
  # zswap only compresses pages that reclaim has already chosen to evict, so the
  # reclaim policy decides how much ends up there:
  # - swappiness 20 (kernel default 60): drop page cache before compressing
  #   anonymous pages, which come back as a fault plus a decompress. Not 0: at 0
  #   the kernel swaps only once free plus file pages fall below the high
  #   watermark, so an anonymous spike ends in an OOM kill instead of zswap.
  # - watermark_scale_factor 100 (default 10): wake kswapd earlier, so it frees
  #   memory ahead of allocation bursts instead of the allocating application
  #   stalling in direct reclaim.
  # - watermark_boost_factor 0 (default 15000): skip the extra reclaim that
  #   fragmentation triggers, which keeps evicting pages on an aging system.
  boot.kernel.sysctl = {
    "vm.swappiness" = 20;
    "vm.watermark_scale_factor" = 100;
    "vm.watermark_boost_factor" = 0;
  };

  # Let oomd watch the whole user slice, so a runaway browser session gets cut
  # before the desktop hard-stalls under memory pressure.
  systemd.oomd.enableUserSlices = lib.mkForce true;

  networking = {
    inherit hostName;

    # VR_TODO:
    # we use NetworkManager
    # how to use networkd?
    networkmanager.enable = true; # provides nmcli/nmtui for wifi adjustment
    # Let NetworkManager own DHCP; dhcpcd races with it and can leave DNS stale.
    useDHCP = lib.mkForce false;
    dhcpcd.enable = false;
  };

  # The shared firewall (modules/nixos/base/networking/firewall.nix) trusts only
  # lanCidr, upstream's 192.168.5.0/24, and drops every per-service port. eva's
  # LAN is 192.168.1.0/24, so open just the services the LAN used before:
  # SSH, Sunshine (the ports its module opens for the default port 47989) and
  # mDNS. Everything else from the LAN stays denied; the tailnet keeps full access.
  networking.firewall.extraInputRules = ''
    ip saddr 192.168.1.0/24 tcp dport { 22, 47984, 47989, 47990, 48010 } accept
    ip saddr 192.168.1.0/24 udp dport { 5353, 47998, 47999, 48000, 48002, 48010 } accept
  '';

  # Upstream purges trash older than 30 days daily (modules/nixos/base/trash.nix).
  # Here ~/.local/share, and with it the home trash, is persistent, so the purge
  # would delete real files; the user empties the trash by hand.
  systemd.services.trash-empty.enable = false;
  systemd.timers.trash-empty.enable = false;

  # Keep stopped rootless containers (and their writable layers) until the user
  # removes them; the weekly `podman system prune -f` from
  # modules/nixos/desktop/containers.nix would delete them. The rootful prune stays.
  systemd.user.services.podman-prune.enable = false;
  systemd.user.timers.podman-prune.enable = false;

  # networking.useNetworkd = true;
  # systemd.network.enable = true;

  # Ported from upstream idols-ai. These only take effect if networkd is
  # enabled later; eva currently uses NetworkManager. Do not enable networkd
  # here — that would change the live networking stack.
  # networkd removes routing policy rules not defined in .network files
  # (ManageForeignRoutingPolicyRules defaults to yes) each time it reconfigures
  # a link. Keep foreign rules so VPN/TUN (mihomo/Tailscale) rules survive.
  systemd.network.config.networkConfig.ManageForeignRoutingPolicyRules = false;

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
      # r8169 drops carrier on S3 resume; without this, networkd tears down the
      # static address/route and clash's TUN auto-detect briefly loses its
      # outbound interface, leaving routing broken until clash is restarted.
      IgnoreCarrierLoss = "10s";
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
