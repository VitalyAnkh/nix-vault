{
  lib,
  outputs,
  ...
}:
let
  configs = outputs.nixosConfigurations;
  # Upstream lists ai-niri; eva and muon are its local successors here. youko
  # is absent without the private secrets input (12kingdoms-youko.nix).
  physicalHosts = builtins.filter (name: configs ? ${name}) [
    "aquamarine"
    "eva"
    "eva-niri"
    "muon"
    "muon-niri"
    "shoryu"
    "shushou"
    "youko"
  ];
in
{
  governors = lib.genAttrs physicalHosts (
    name: configs.${name}.config.powerManagement.cpuFreqGovernor
  );
  noTuned = lib.all (host: !host.config.services.tuned.enable) (builtins.attrValues configs);
  noEeeWorkaround = lib.all (host: !(host.config.systemd.services ? disable-eee)) (
    builtins.attrValues configs
  );
  noFrequencyCaps = lib.all (
    name:
    let
      cfg = configs.${name}.config.powerManagement;
    in
    cfg.cpufreq.min == null && cfg.cpufreq.max == null
  ) physicalHosts;
  guestsHaveNoCpuPolicy = lib.all (name: !(configs.${name}.config.systemd.services ? cpufreq)) (
    lib.subtractLists physicalHosts (builtins.attrNames configs)
  );
  desktopBatteryReporting = configs.eva.config.services.upower.enable;
}
