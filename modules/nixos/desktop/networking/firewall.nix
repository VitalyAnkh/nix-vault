# Desktops hold personal data and laptops join untrusted networks, so keep the
# firewall enabled here (repo-wide default is on, see modules/nixos/base/ssh.nix).
# The base firewall (modules/nixos/base/networking/firewall.nix) forces the port
# lists below and drops every per-service `openFirewall` port; LAN access comes
# from its lanCidr rule or from host rules (hosts/eva/default.nix).
{ lib, ... }:
{
  networking.firewall = {
    enable = true;
    # Trust everything from the tailnet.
    trustedInterfaces = [ "tailscale0" ];
    # Preserve the local desktop services that were intentionally reachable
    # before the shared default-deny firewall was introduced upstream.
    allowedTCPPorts = lib.mkForce [
      53317
      63080
      63081
      63082
      63083
      63084
      63085
      63086
      63087
      63088
      63089
    ];
  };
}
