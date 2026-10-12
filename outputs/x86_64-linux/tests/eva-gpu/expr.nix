{
  lib,
  myvars,
  outputs,
  ...
}:
let
  cfg = outputs.nixosConfigurations.eva.config;
  username = myvars.username;
  userDirs = cfg.preservation.preserveAt."/persistent".users.${username}.directories or [ ];
  dirName = d: if builtins.isString d then d else (d.directory or "");
  dirNames = map dirName userDirs;
  hasDirSuffix = suffix: builtins.any (n: lib.hasSuffix suffix n) dirNames;
in
{
  sunshineEnabled = cfg.services.sunshine.enable;
  sunshineHasSysAdmin = cfg.services.sunshine.capSysAdmin;
  sunshineUsesNvencPreset = cfg.services.sunshine.settings.nvenc_preset or null;
  sunshineUsesNvencTwopass = cfg.services.sunshine.settings.nvenc_twopass or null;
  loadsVirtualDisplay = builtins.elem "vkms" cfg.boot.kernelModules;
  # Upstream ai's memory scheme: the disk swapfile behind zswap, no zram.
  zramEnabled = cfg.zramSwap.enable;
  zswapEnabled = cfg.boot.zswap.enable;
  swapDevices = map (s: s.device) cfg.swapDevices;
  # Installer-only disko: the mounts stay those of hardware-configuration.nix.
  diskoEnablesConfig = cfg.disko.enableConfig;
  preservesMoonlight = hasDirSuffix ".config/Moonlight Game Streaming Project";
  permitRootLogin = cfg.services.openssh.settings.PermitRootLogin;
  passwordAuth = cfg.services.openssh.settings.PasswordAuthentication;
}
