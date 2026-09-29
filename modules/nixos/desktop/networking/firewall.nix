# Desktops hold personal data and laptops join untrusted networks, so keep the
# firewall enabled here (repo-wide default is on, see modules/nixos/base/ssh.nix).
# SSH/Tailscale/LocalSend/Sunshine keep working via their own `openFirewall` options.
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
