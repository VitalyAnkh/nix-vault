{ outputs, ... }:
# youko needs the private secrets input; skip it when it is absent.
if outputs.nixosConfigurations ? youko then
  let
    systemd = outputs.nixosConfigurations.youko.config.systemd.package;
  in
  {
    wantsMountsFor = [
      "/data/apps"
      "/data/apps-snapshots"
      "/data/backups"
      "/data/fileshare"
      "/data/fileshare/public"
    ];
    execStart = "${systemd}/bin/systemd-tmpfiles --create --remove --boot --prefix=/data";
    setupWaitsForData = false;
  }
else
  { }
