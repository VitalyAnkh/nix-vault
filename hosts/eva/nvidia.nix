{ config, ... }:
{
  # ===============================================================================================
  # for Nvidia GPU
  # https://wiki.nixos.org/wiki/NVIDIA
  # https://wiki.hyprland.org/Nvidia/
  # ===============================================================================================

  boot.kernelParams = [
    # Since NVIDIA does not load kernel mode setting by default,
    # enabling it is required to make Wayland compositors function properly.
    # "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
    "nvidia-drm.fbdev=1"
  ];
  services.xserver.videoDrivers = [ "nvidia" ]; # will install nvidia-vaapi-driver by default
  hardware.nvidia = {
    # Open-source kernel modules are preferred over and planned to steadily replace proprietary modules
    open = true;
    # Optionally, you may need to select the appropriate driver version for your specific GPU.
    # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/os-specific/linux/nvidia-x11/default.nix
    package = config.boot.kernelPackages.nvidiaPackages.beta;

    # required by most wayland compositors!
    modesetting.enable = true;
    powerManagement = {
      enable = true;
      # finegrained = true;
    };
    # prime = {
    #   offload.enable = true;
    #   # Bus ID of the NVIDIA GPU. You can find it using lspci, either under 3D or VGA
    #   nvidiaBusId = "PCI:00:01:00";
    #   # Bus ID of the AMD GPU. You can find it using lspci, either under 3D or VGA
    #   amdgpuBusId = "PCI:00:7a:00";
    # };
  };

  hardware.nvidia-container-toolkit.enable = true;
  hardware.graphics = {
    enable = true;
    # needed by nvidia-docker
    enable32Bit = true;
  };
  # disable cudasupport before this issue get fixed:
  # https://github.com/NixOS/nixpkgs/issues/338315
  nixpkgs.config.cudaSupport = true;

  # nixpkgs.overlays = [
  #   (_: super: {
  #     blender = pkgs-unstable.blender.override {
  #       # https://nixos.org/manual/nixpkgs/unstable/#opt-cudaSupport
  #       cudaSupport = true;
  #     };

  #     ffmpeg-full = super.ffmpeg-full.override {
  #       withNvcodec = true;
  #     };
  #   })
  # ];

  nixpkgs.overlays = [
    (_: super: {
      # ffmpeg-full = super.ffmpeg-full.override {
      #   withNvcodec = true;
      # };
    })
  ];
}
