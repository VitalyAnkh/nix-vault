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
  desktopBatteryReporting = true;
}
