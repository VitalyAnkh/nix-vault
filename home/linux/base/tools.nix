{
  lib,
  pkgs,
  ...
}:
{
  # Linux Only Packages, not available on Darwin
  home.packages =
    with pkgs;
    [
      # misc
      libnotify
      wireguard-tools # manage wireguard vpn manually, via wg-quick

      # create bootable usb
      # insecure for now, see:
      # https://github.com/ventoy/Ventoy/issues/2795
      # https://github.com/ventoy/Ventoy/issues/3224
      # ventoy
      virt-viewer # vnc connect to VM, used by kubevirt

      # cross compiling rust
      # cargo-xwin
    ]
    # CUDA EULA packages are available on desktop profiles that explicitly allow
    # unfree software, but must stay out of the open-source server/microVM profile.
    ++ lib.optionals (pkgs.config.allowUnfree or false) [
      (lib.setPrio 10 cudaPackages.cudatoolkit)
      (lib.setPrio 20 cudaPackages.nsight_compute)
      (lib.setPrio 30 (
        cudaPackages.nsight_systems.override { ucx = ucx.override { enableCuda = false; }; }
      ))
    ];

  # auto mount usb drives
  services = {
    udiskie.enable = true;
    syncthing.enable = true;
  };
}
