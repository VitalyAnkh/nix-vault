{
  lib,
  outputs,
}:
let
  specialExpected = {
    "eva" = "eva";
    # eva-niri is an "eva" variant (different desktop stack), so the actual hostName stays "eva".
    "eva-niri" = "eva";
    "muon" = "muon";
    # "ai-hyprland" = "ai";
    # "ai-niri" = "ai";
  };
  specialHostNames = builtins.attrNames specialExpected;

  otherHosts = builtins.removeAttrs outputs.nixosConfigurations specialHostNames;
  otherHostsNames = builtins.attrNames otherHosts;
  # other hosts's hostName is the same as the nixosConfigurations name
  otherExpected = lib.genAttrs otherHostsNames (name: name);
in
(specialExpected // otherExpected)
