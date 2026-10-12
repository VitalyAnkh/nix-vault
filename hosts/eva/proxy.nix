{
  config,
  lib,
  pkgs-master,
  ...
}:
# TUN proxy for eva and muon.
#
# Upstream replaced Clash Verge with its native mihomo service
# (modules/nixos/desktop/networking/mihomo): the GUI crashed (SIGFPE) and
# reopened a fake-IP leak window on every core restart. That service loads
# ~/.config/mihomo/config.yaml, which `just mihomo-gen` renders from the private
# ~/.config/mihomo/sources.yaml (subscriptions, secret), and it does not start
# without it. These hosts have no sources.yaml yet, so Clash Verge stays the
# default; set `vr.proxy.backend = "mihomo"` once the config can be generated
# (steps in docs/upstream-sync.md).
#
# NOTE: There is a known pitfall with mihomo's fake-IP for IPv6
# (fake-ip-range6: fdfe:dcba:9876::/64): TCP connections to IPv6 fake-IPs are
# not proxied correctly and simply hang until connect() times out.
# Clients without a fast IPv4 fallback stall for ~2 minutes per attempt:
# every git remote operation (fetch/pull/push alike, they all go through ssh)
# hangs on "Connecting to ssh.github.com [fdfe:dcba:9876::x] port 443"
# before falling back to IPv4.
# Browsers recover silently thanks to Happy Eyeballs (RFC 8305: when a name
# resolves to both IPv4 and IPv6, the client tries one stack first, then races
# the other after a ~50ms delay and keeps whichever connects first).
# Fix: disable IPv6 in Clash Verge's DNS/TUN settings (confirmed working);
# or work around per-client, e.g. `AddressFamily inet` in ssh_config
# (see home/base/tui/ssh.nix).
let
  cfg = config.vr.proxy;
in
{
  options.vr.proxy.backend = lib.mkOption {
    type = lib.types.enum [
      "clash-verge"
      "mihomo"
    ];
    default = "clash-verge";
    description = "The TUN proxy on this host: Clash Verge, or upstream's native mihomo service.";
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.backend == "clash-verge") {
      programs.clash-verge = {
        enable = true;
        package = pkgs-master.clash-verge-rev;
        autoStart = false;
        serviceMode = true;
        tunMode = true;
      };
    })
    (lib.mkIf (cfg.backend == "mihomo") {
      modules.networking.mihomo.enable = true;
    })
  ];
}
