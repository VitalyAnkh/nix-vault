{
  lib,
  outputs,
  ...
}:
{
  governors = lib.genAttrs (builtins.filter (name: outputs.nixosConfigurations ? ${name}) [
    "aquamarine"
    "eva"
    "eva-niri"
    "muon"
    "muon-niri"
    "shoryu"
    "shushou"
    "youko"
  ]) (_: "powersave");
  noTuned = true;
  noEeeWorkaround = true;
  noFrequencyCaps = true;
  guestsHaveNoCpuPolicy = true;
  serverRaplEnabled = lib.genAttrs (builtins.filter (name: outputs.nixosConfigurations ? ${name}) [
    "aquamarine"
    "shoryu"
    "shushou"
    "youko"
  ]) (_: true);
  serverRaplReaderOnly = true;
  desktopRaplDisabled = true;
  guestsHaveNoRapl = true;
  desktopBatteryReporting = true;
}
