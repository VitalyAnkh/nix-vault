{
  lib,
  pkgs,
  pkgs-unstable,
  ...
}:
{
  # Linux Only Packages, not available on Darwin
  home.packages = with pkgs; [
    # misc
    libnotify
    wireguard-tools # manage wireguard vpn manually, via wg-quick

    # create bootable usb
    # insecure for now, see:
    # https://github.com/ventoy/Ventoy/issues/2795
    # https://github.com/ventoy/Ventoy/issues/3224
    # ventoy
    virt-viewer # vnc connect to VM, used by kubevirt

    pkgs-unstable.cudaPackages.cudatoolkit
    pkgs-unstable.cudaPackages.nsight_systems
    (lib.hiPrio pkgs-unstable.cudaPackages.nsight_compute)
  ];

  # auto mount usb drives
  services = {
    udiskie.enable = true;
    syncthing.enable = true;
  };
}
