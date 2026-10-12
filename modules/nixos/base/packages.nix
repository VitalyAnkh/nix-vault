{
  config,
  lib,
  pkgs,
  ...
}:
let
  debugTools = config.modules.debugTools;
in
{
  options.modules.debugTools.enable = lib.mkEnableOption ''
    Tracing and benchmarking tools (strace, bpftrace, sysstat, iotop-c,
    sysbench and the BCC tools).

    Off by default: opt in on hosts where you actually profile them.
  '';

  config = {
    # List packages installed in system profile. To search, run:
    # $ nix search wget
    environment.systemPackages = with pkgs; [
      # system call monitoring
      strace
      ltrace
      lsof

      # ebpf related tools
      bpftrace
      bpftop
      bpfmon

      # system monitoring
      sysstat
      iotop-c
      iftop
      nmon
      sysbench
      systemctl-tui
      pv

      # system tools
      psmisc
      lm_sensors
      ethtool
      pciutils
      usbutils
      hdparm
      dmidecode
      parted
      smartmontools
      nvme-cli
    ];

    # BCC - Tools for BPF-based Linux IO analysis, networking, monitoring, and more.
    programs.bcc.enable = debugTools.enable;
  };
}
