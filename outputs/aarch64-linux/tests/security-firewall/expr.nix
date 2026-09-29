{
  myvars,
  lib,
  outputs,
}:
lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (
  name:
  let
    firewall = outputs.nixosConfigurations.${name}.config.networking.firewall;
    desktopPorts = [
      53317
      63080
      63081
      63082
      63083
      63084
      63085
      63086
      63087
      63088
      63089
    ];
  in
  # Every host must run the shared firewall (modules/nixos/base/networking/
  # firewall.nix): enabled, trusting the LAN by source, and either opening
  # nothing globally or using the explicit desktop service allowlist.
  firewall.enable
  && lib.hasInfix myvars.networking.lanCidr firewall.extraInputRules
  && (firewall.allowedTCPPorts == [ ] || firewall.allowedTCPPorts == desktopPorts)
  && firewall.allowedUDPPorts == [ ]
)
