{
  outputs,
  ...
}:
# youko needs the private secrets input; skip it when it is absent.
if outputs.nixosConfigurations ? youko then
  let
    services = outputs.nixosConfigurations.youko.config.systemd.services;
    unit = services.data-tmpfiles;
  in
  {
    wantsMountsFor = builtins.sort builtins.lessThan unit.unitConfig.WantsMountsFor;
    execStart = unit.serviceConfig.ExecStart;
    setupWaitsForData =
      (services.systemd-tmpfiles-setup or { }).unitConfig.RequiresMountsFor or [ ] != [ ];
  }
else
  { }
