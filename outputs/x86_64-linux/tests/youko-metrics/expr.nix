{
  lib,
  outputs,
}:
if outputs.nixosConfigurations ? youko then
  let
    aqua = outputs.nixosConfigurations.youko.config;
  in
  {
    pgExporter = aqua.services.prometheus.exporters.postgres.listenAddress;
    sftpgoTelemetry = aqua.services.sftpgo.settings.telemetry.bind_address;
  }
else
  { }
