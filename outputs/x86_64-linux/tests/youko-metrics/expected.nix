{ outputs, ... }:
if outputs.nixosConfigurations ? youko then
  {
    pgExporter = "127.0.0.1";
    sftpgoTelemetry = "127.0.0.1";
  }
else
  { }
