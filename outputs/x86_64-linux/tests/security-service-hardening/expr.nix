{ lib, outputs }:
let
  keys = [
    "CapabilityBoundingSet"
    "NoNewPrivileges"
    "PrivateDevices"
    "ProtectSystem"
    "SystemCallFilter"
  ];
  units =
    host: names:
    lib.genAttrs names (
      n: lib.getAttrs keys outputs.nixosConfigurations.${host}.config.systemd.services.${n}.serviceConfig
    );
in
# youko needs the private secrets input; skip its units when it is absent.
lib.optionalAttrs (outputs.nixosConfigurations ? youko) (
  units "youko" [
    "caddy"
    "rustfs"
    "vmalert-homelab"
  ]
)
// units "aquamarine" [ "whisper-asr" ]
