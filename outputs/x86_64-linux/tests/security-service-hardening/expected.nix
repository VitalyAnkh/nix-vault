{ outputs, ... }:
let
  sandbox = {
    CapabilityBoundingSet = "";
    NoNewPrivileges = true;
    PrivateDevices = true;
    ProtectSystem = "strict";
    SystemCallFilter = [
      "@system-service"
      "~@clock @cpu-emulation @debug @module @mount @obsolete @privileged @raw-io @reboot @swap"
    ];
  };
in
# youko needs the private secrets input; skip its units when it is absent.
(
  if outputs.nixosConfigurations ? youko then
    {
      # Only 80/443.
      caddy = sandbox // {
        CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
      };
      rustfs = sandbox;
      vmalert-homelab = sandbox;
    }
  else
    { }
)
// {
  # The NPU is allowed through DeviceAllow instead.
  whisper-asr = sandbox // {
    PrivateDevices = false;
  };
}
