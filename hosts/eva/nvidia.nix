{ config, lib, ... }:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    optional
    optionalAttrs
    types
    ;

  cfg = config.vr.hosts.eva.nvidia.primeOffload;
  dynamicBoostCfg = config.vr.hosts.eva.nvidia.dynamicBoost;
in
{
  options.vr.hosts.eva.nvidia.primeOffload = {
    enable = mkEnableOption ''
      optional PRIME offload mode for eva.

      Leave this disabled on the current AMD CPU + NVIDIA GPU desktop path so
      NVIDIA remains the default GPU.
    '';

    intelBusId = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "PCI:0@0:2:0";
      description = "Intel iGPU Bus ID to use when PRIME offload is explicitly enabled.";
    };

    amdgpuBusId = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "PCI:0@0:7:0";
      description = "AMD iGPU Bus ID to use when PRIME offload is explicitly enabled.";
    };

    nvidiaBusId = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "PCI:2@0:0:0";
      description = "NVIDIA dGPU Bus ID to use when PRIME offload is explicitly enabled.";
    };
  };

  options.vr.hosts.eva.nvidia.dynamicBoost.enable = mkEnableOption ''
    NVIDIA Dynamic Boost on eva.

    Keep this disabled by default on the current desktop GPU path because it
    starts nvidia-powerd, which is intended for supported laptops.
  '';

  config = {
    # ===============================================================================================
    # for Nvidia GPU
    # https://wiki.nixos.org/wiki/NVIDIA
    # https://wiki.hyprland.org/Nvidia/
    # ===============================================================================================

    boot.kernelParams = [
      # Since NVIDIA does not load kernel mode setting by default,
      # enabling it is required to make Wayland compositors function properly.
      # "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
      "nvidia.NVreg_RestrictProfilingToAdminUsers=0"
      "nvidia-drm.fbdev=1"
    ];
    services.xserver.videoDrivers = [ "nvidia" ]; # will install nvidia-vaapi-driver by default
    hardware.nvidia = {
      # Open-source kernel modules are preferred over and planned to steadily replace proprietary modules
      open = true;
      nvidiaSettings = true;
      # Optionally, you may need to select the appropriate driver version for your specific GPU.
      # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/os-specific/linux/nvidia-x11/default.nix
      package = config.boot.kernelPackages.nvidiaPackages.beta;

      # required by most wayland compositors!
      modesetting.enable = true;
      powerManagement = {
        enable = true;
        # finegrained = true;
      };
      dynamicBoost.enable = dynamicBoostCfg.enable;
      prime = mkIf cfg.enable (
        {
          # Keep PRIME offload opt-in on eva; the default path uses the NVIDIA dGPU directly.
          offload = {
            enable = true;
            enableOffloadCmd = true;
          };
        }
        // optionalAttrs (cfg.nvidiaBusId != null) {
          nvidiaBusId = cfg.nvidiaBusId;
        }
        // optionalAttrs (cfg.intelBusId != null) {
          intelBusId = cfg.intelBusId;
        }
        // optionalAttrs (cfg.amdgpuBusId != null) {
          amdgpuBusId = cfg.amdgpuBusId;
        }
      );
    };

    assertions =
      optional cfg.enable {
        assertion = cfg.nvidiaBusId != null;
        message = "eva PRIME offload requires `vr.hosts.eva.nvidia.primeOffload.nvidiaBusId`.";
      }
      ++ optional cfg.enable {
        assertion = cfg.intelBusId != null || cfg.amdgpuBusId != null;
        message = ''
          eva PRIME offload requires either
          `vr.hosts.eva.nvidia.primeOffload.intelBusId` or
          `vr.hosts.eva.nvidia.primeOffload.amdgpuBusId`.
        '';
      };

    hardware.nvidia-container-toolkit.enable = true;
    hardware.graphics = {
      enable = true;
      # needed by nvidia-docker
      enable32Bit = true;
    };

    nixpkgs.config.cudaSupport = true;

    nixpkgs.overlays = [
      (_: super: {
        ffmpeg-full = super.ffmpeg-full.override {
          withNvcodec = true;
        };
      })
    ];

    services.sunshine.settings = {
      max_bitrate = 20000; # in Kbps
      # NVIDIA NVENC Encoder
      nvenc_preset = 3; # 1(fastest + worst quality) - 7(slowest + best quality)
      nvenc_twopass = "full_res"; # quarter_res / full_res.
    };
  };
}
