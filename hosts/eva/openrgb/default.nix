{ pkgs, ... }:
let
  offProfile = ./off.json;
in
{
  # The board's ARGB controller is Gigabyte RGB Fusion, a USB HID device (ITE
  # 048d:5711). This installs openrgb with its udev rules and runs `openrgb
  # --server`, so the GUI and the CLI reach the board without root. `motherboard`
  # follows hardware.cpu.amd.updateMicrocode, which loads i2c-piix4 for the SMBus.
  #
  # As on upstream's ai host, load a profile after detection that turns every LED
  # off, on every boot.
  services.hardware.openrgb = {
    enable = true;
    startupProfile = "off";
  };

  # Keep the profile checked in, and install it before the server starts. An
  # empty controller list with base_color = 0 makes OpenRGB apply black to every
  # detected controller.
  systemd.services.openrgb.preStart = ''
    ${pkgs.coreutils}/bin/install -Dm0644 ${offProfile} /var/lib/OpenRGB/profiles/off.json
  '';

  # A controller can drop its LED state on resume without re-enumerating, so no
  # udev event fires; reapply the profile through the running server instead.
  systemd.services.openrgb-resume = {
    description = "Reapply the OpenRGB profile after resume";
    after = [ "suspend.target" ];
    wantedBy = [ "suspend.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.openrgb}/bin/openrgb --profile ${offProfile}";
    };
  };
}
