{ lib, ... }:
# Hardware watchdog for eva and muon.
#
# modules/nixos/watchdog.nix arms the board watchdog on every desktop host
# (RuntimeWatchdogSec = 30s) and reboots 20 s after a kernel panic. The panic
# reboot and journald's 5 s sync apply here as well; the runtime watchdog stays
# off until a suspend longer than 30 s has been tested: upstream has not
# verified that the watchdog pauses during sleep (WA-052), and eva's SP5100 TCO
# timer would reset the host mid-suspend if it keeps counting. To arm it,
# remove this module and confirm `cat /sys/class/watchdog/watchdog0/state` is
# "active" and the host survives a suspend of a few minutes.
{
  systemd.settings.Manager.RuntimeWatchdogSec = lib.mkForce "off";
}
