{
  lib,
  pkgs,
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

    # CUDA packages with proper priority to avoid conflicts
    # cudatoolkit has highest priority (lowest number)
    (lib.setPrio 10 cudaPackages.cudatoolkit)
    # nsight_compute has medium priority
    (lib.setPrio 20 cudaPackages.nsight_compute)
    (lib.setPrio 30 (
      cudaPackages.nsight_systems.override { ucx = ucx.override { enableCuda = false; }; }
    ))

    # cross compiling rust
    # cargo-xwin
  ];

  # auto mount usb drives
  services = {
    udiskie.enable = true;
    syncthing.enable = true;
  };
}
