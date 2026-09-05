{
  lib,
  outputs,
}:
let
  desktopHosts = [
    "shoukei-niri"
    "eva"
    "eva-niri"
    "muon"
  ];
  keepRootLogin = [
    "eva"
    "eva-niri"
    "muon"
  ];
in
lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (
  name:
  let
    isDesktop = builtins.elem name desktopHosts;
  in
  {
    X11Forwarding = isDesktop;
    PermitRootLogin =
      if builtins.elem name keepRootLogin then
        "prohibit-password"
      else if isDesktop then
        "no"
      else
        "prohibit-password";
  }
)
