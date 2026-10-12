{
  lib,
  myvars,
  outputs,
  ...
}:
let
  cfg = outputs.nixosConfigurations."eva-niri".config;
  niriHardware = builtins.readFile ../../../../hosts/eva/niri-hardware.kdl;
  preserved = cfg.preservation.preserveAt."/persistent".users.${myvars.username}.directories;
  privatelyPreserved =
    path:
    lib.any (
      d:
      let
        directory = if builtins.isString d then d else d.directory;
        mode = if builtins.isString d then null else d.mode;
      in
      (directory == path || directory == cfg.users.users.${myvars.username}.home + "/" + path)
      && (mode == null || mode == "0700")
    ) preserved;
in
{
  loadsVirtualDisplay = builtins.elem "vkms" cfg.boot.kernelModules;
  createsVirtualDisplay = lib.hasInfix "options vkms create_default_dev=1" cfg.boot.extraModprobeConfig;
  niriUsesIntelRenderer = lib.hasInfix "/dev/dri/by-path/pci-0000:00:02.0-render" niriHardware;
  sunshineUserHasInputAccess = builtins.elem "input" cfg.users.users.${myvars.username}.extraGroups;
  sunshineHasSysAdmin = cfg.services.sunshine.capSysAdmin;
  sunshineUsesWlrCapture = cfg.services.sunshine.settings.capture;
  wivrnEnabled = cfg.services.wivrn.enable;
  wivrnAutoStarts = builtins.elem "default.target" cfg.systemd.user.services.wivrn.wantedBy;
  wivrnHighPriority = cfg.services.wivrn.highPriority;
  wivrnWaitsForBus =
    cfg.systemd.user.services.wivrn.serviceConfig.Type == "dbus"
    && cfg.systemd.user.services.wivrn.serviceConfig.BusName == "io.github.wivrn.Server"
    && cfg.systemd.user.services.wivrn.serviceConfig.TimeoutStartSec == "30s";
  wivrnImportsOpenXRToSteam =
    cfg.environment.sessionVariables.PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES == "1";
  wivrnUsesNvidiaVulkan = cfg.services.wivrn.monadoEnvironment.__VK_LAYER_NV_optimus == "NVIDIA_only";
  wivrnStatePreserved = privatelyPreserved ".config/wivrn";
  adbStatePreserved = privatelyPreserved ".android";
}
