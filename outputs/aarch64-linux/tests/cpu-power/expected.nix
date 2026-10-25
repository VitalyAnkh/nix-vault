{
  outputs,
  ...
}:
{
  # Upstream expects the Apple module's schedutil. Here the module is off unless
  # the my-asahi-firmware input exists (hosts/12kingdoms-shoukei/apple-silicon.nix),
  # and without it hardware-configuration.nix's powersave applies.
  governor =
    if outputs.nixosConfigurations.shoukei-niri.config.hardware.asahi.enable then
      "schedutil"
    else
      "powersave";
  noTuned = true;
  noFrequencyCaps = true;
  batteryReporting = true;
}
