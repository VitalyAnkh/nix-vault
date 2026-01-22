{
  pkgs,
  lib,
  ...
}:
let
  mkMonitorsXmlSync =
    {
      name,
      srcRel,
      dstRel,
    }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [ pkgs.coreutils ];
      text = ''
        set -euo pipefail

        src="$HOME/${srcRel}"
        dst="$HOME/${dstRel}"

        if [[ -s "$src" ]]; then
          mkdir -p "$(dirname "$dst")"
          install -m 0644 -T "$src" "$dst"
        fi
      '';
    };

  restoreMonitorsXml = mkMonitorsXmlSync {
    name = "restore-gnome-monitors-xml";
    srcRel = ".local/state/gnome/monitors.xml";
    dstRel = ".config/monitors.xml";
  };

  persistMonitorsXml = mkMonitorsXmlSync {
    name = "persist-gnome-monitors-xml";
    srcRel = ".config/monitors.xml";
    dstRel = ".local/state/gnome/monitors.xml";
  };
in
{
  environment.systemPackages = with pkgs; [
    digital
    gnomeExtensions.appindicator
    gnome-extension-manager
    gnomeExtensions.quake-terminal
    gnomeExtensions.clipboard-history
    gnomeExtensions.kimpanel
    gnomeExtensions.user-themes
    gnome-screenshot
    clash-verge-rev
    clash-nyanpasu
    # hiddify-app
    flclash
    kdiskmark
    # daed
    warp-terminal
    zotero
    kdePackages.okular
    v2raya
    zulip
  ];

  # Persist GNOME monitor layout/scaling (monitors.xml) on a stateless root.
  #
  # NOTE: Do NOT bind-mount ~/.config/monitors.xml as a file: GNOME writes it via
  # atomic rename, which fails if the destination is a mountpoint. Instead, keep a
  # persisted copy under ~/.local/state (already preserved) and sync it on login
  # and whenever the file changes.
  systemd.user.services.restore-gnome-monitors-xml = {
    description = "Restore GNOME monitors.xml from persistent state";
    wantedBy = [ "default.target" ];
    before = [
      "graphical-session-pre.target"
      "org.gnome.Shell@wayland.service"
      "org.gnome.Shell@x11.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe restoreMonitorsXml;
    };
  };

  systemd.user.services.persist-gnome-monitors-xml = {
    description = "Persist GNOME monitors.xml to ~/.local/state";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe persistMonitorsXml;
    };
  };

  systemd.user.paths.persist-gnome-monitors-xml = {
    description = "Watch GNOME monitors.xml changes";
    wantedBy = [ "graphical-session-pre.target" ];
    before = [ "graphical-session-pre.target" ];
    pathConfig.PathChanged = "%h/.config/monitors.xml";
  };
}
