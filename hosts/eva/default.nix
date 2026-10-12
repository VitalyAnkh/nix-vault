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

  inherit (myvars.networking) nameservers;
  inherit (myvars.networking.hostsAddr.${hostName}) iface;
in
{
  imports = [
    ./netdev-mount.nix
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    disko.nixosModules.default
    ./disko-fs.nix
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

  # Allow SSH password authentication on eva.
  # Keep root usable for remote deployment; do not inherit desktop PermitRootLogin = no.
  services.openssh.settings = {
    PasswordAuthentication = lib.mkForce true;
    PermitRootLogin = lib.mkForce "prohibit-password";
  };

  services.sunshine.enable = lib.mkForce true;
  services.tuned.ppdSettings.main.default = lib.mkForce "performance";

  # Keep the NVIDIA root port out of PCIe power-saving paths. Repeated Xid 79
  # freezes showed the GPU disappearing from the PCIe bus, and live sampling
  # previously showed corrected TLP errors before failure.
  boot.kernelParams = [
    "pcie_aspm=off"
    "pcie_port_pm=off"
  ];

  # Follow the upstream AI memory strategy: disk-backed swap avoids a zram
  # deadlock while large GPU/LLM workloads reclaim memory. zswap remains a
  # compressed writeback cache in front of the disk swapfile.
  modules.zram.enable = lib.mkForce false;
  boot.zswap = {
    enable = true;
    compressor = "zstd";
    maxPoolPercent = 10;
  };
  boot.kernel.sysctl = {
    "vm.swappiness" = lib.mkForce 60;
    "vm.watermark_scale_factor" = lib.mkForce 50;
  };

  # Let oomd watch the whole user slice, so a runaway browser session gets cut
  # before the desktop hard-stalls under RAM+zram pressure.
  systemd.oomd.enableUserSlices = lib.mkForce true;

  networking = {
    inherit hostName;

    # Keep NetworkManager for EVA's roaming Wi-Fi. networkd owns only the wired
    # uplink below, so a Wi-Fi-to-Ethernet move remains usable.
    networkmanager.enable = true;
    networkmanager.unmanaged = [ "interface-name:${iface}" ];
    useDHCP = lib.mkForce false;
    dhcpcd.enable = false;
  };

  # Explicit .network files are enabled while the scripted backend remains off;
  # this lets networkd manage enp15s0 and leaves Wi-Fi to NetworkManager.
  networking.useNetworkd = false;
  systemd.network.enable = true;

  # networkd removes routing policy rules not defined in .network files
  # (ManageForeignRoutingPolicyRules defaults to yes) each time it reconfigures
  # a link. Keep foreign rules so VPN/TUN (mihomo/Tailscale) rules survive.
  systemd.network.config.networkConfig.ManageForeignRoutingPolicyRules = false;

  systemd.network.networks."10-${iface}" = {
    matchConfig.Name = [ iface ];
    networkConfig = {
      DNS = nameservers;
      DHCP = "yes";
      IPv6AcceptRA = true;
      LinkLocalAddressing = "ipv6";
      # r8169 drops carrier on S3 resume; without this, networkd tears down the
      # static address/route and mihomo's TUN auto-detect briefly loses its
      # outbound interface, leaving routing broken until mihomo is restarted.
      IgnoreCarrierLoss = "10s";
    };
    linkConfig.RequiredForOnline = "routable";
  };

  # Point resolved at mihomo only after the core has opened its DNS listener;
  # revert on clean shutdown and crashes so a failed proxy never strands DNS.
  systemd.services.mihomo.serviceConfig = {
    ExecStartPost = lib.mkDefault "+${pkgs.writeShellScript "eva-mihomo-dns-takeover" ''
      link_file=/run/mihomo-dns-link
      probe() { (exec 3<>/dev/tcp/127.0.0.1/1053) 2>/dev/null; }
      up=0
      for ((i = 0; i < 100; i++)); do
        if probe; then up=1; break; fi
        sleep 0.1
      done
      if [ "$up" = 0 ]; then
        echo "mihomo did not open 127.0.0.1:1053; leaving ${iface} DNS unchanged" >&2
        exit 0
      fi
      link="$(${pkgs.iproute2}/bin/ip -4 route show default | ${pkgs.gawk}/bin/awk 'NR == 1 { print $5 }')"
      link="''${link:-${iface}}"
      if ! ${pkgs.iproute2}/bin/ip link show "$link" >/dev/null 2>&1; then
        echo "mihomo DNS takeover found no usable uplink; leaving DNS unchanged" >&2
        exit 0
      fi
      printf '%s\n' "$link" > "$link_file"
      exec ${pkgs.systemd}/bin/resolvectl dns "$link" 127.0.0.1:1053
    ''}";
    ExecStopPost = lib.mkDefault "+${pkgs.writeShellScript "eva-mihomo-dns-revert" ''
      link_file=/run/mihomo-dns-link
      if [ -r "$link_file" ]; then
        link=$(${pkgs.coreutils}/bin/cat "$link_file")
        ${pkgs.systemd}/bin/resolvectl revert "$link" || true
        ${pkgs.coreutils}/bin/rm -f "$link_file"
      fi
    ''}";
  };

  services.smartd.enable = true;

  # EVA's checked-in hardware scan remains authoritative at runtime. The Disko
  # profile is available for an explicitly requested reinstall/mount, but must
  # not generate a second set of fileSystems or swap units during activation.
  disko.enableConfig = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?
}
