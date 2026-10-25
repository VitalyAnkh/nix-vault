{ config, lib, ... }:
{
  # Bound the NVIDIA driver's free-buffer pool for niri only, as on upstream ai:
  # the driver never returns freed vidmem, so niri's VRAM grows past 1 GiB
  # (WA-039). Only the -niri variants run niri, and the profile applies at niri's
  # next start. Shared with muon.
  # https://github.com/niri-wm/niri/wiki/Nvidia#high-vram-usage-fix
  environment.etc = lib.mkIf config.programs.niri.enable {
    "nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json".text =
      builtins.toJSON {
        rules = [
          {
            pattern = {
              feature = "procname";
              matches = "niri";
            };
            profile = "Limit Free Buffer Pool On Wayland Compositors";
          }
        ];
        profiles = [
          {
            name = "Limit Free Buffer Pool On Wayland Compositors";
            settings = [
              {
                key = "GLVidHeapReuseRatio";
                value = 0;
              }
            ];
          }
        ];
      };
  };
}
