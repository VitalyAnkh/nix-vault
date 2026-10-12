{ pkgs, ... }:
{
  # Keep the upstream WiVRn CLI packaging, but do not import its Intel PRIME
  # or vkms assumptions. EVA's NVIDIA GPU is the primary renderer.
  services.wivrn = {
    enable = true;
    autoStart = false;
    package = pkgs.symlinkJoin {
      name = "wivrn-cli-${pkgs.wivrn.version}";
      inherit (pkgs.wivrn) version meta;
      paths = [ pkgs.wivrn ];
      postBuild = ''
        rm "$out/bin/wivrn-dashboard" "$out/bin/.wivrn-dashboard-wrapped"
        rm "$out/share/applications/"*.desktop
        test -x "$out/bin/wivrn-server"
        test -x "$out/bin/wivrnctl"
        test ! -e "$out/bin/wivrn-dashboard"
      '';
    };
    highPriority = true;
    steam.importOXRRuntimes = true;
  };

  systemd.user.services.wivrn.serviceConfig = {
    Type = "dbus";
    BusName = "io.github.wivrn.Server";
    TimeoutStartSec = "30s";
  };
}
