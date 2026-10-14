{ lib, outputs, ... }:
let
  eva = outputs.nixosConfigurations.eva.config;
  muon = outputs.nixosConfigurations.muon.config;
  rules = eva.networking.nftables.tables.nixos-fw.content or "";
in
{
  # The shared firewall still trusts upstream's lanCidr only; eva adds its own LAN
  # rules for SSH, Sunshine and mDNS (hosts/eva/default.nix).
  evaUsesNftables = eva.networking.nftables.enable;
  evaLanSsh = lib.hasInfix "ip saddr 192.168.1.0/24 tcp dport { 22, 47984, 47989, 47990, 48010 } accept" rules;
  evaLanUdp = lib.hasInfix "ip saddr 192.168.1.0/24 udp dport { 5353, 47998, 47999, 48000, 48002, 48010 } accept" rules;
  # Per-service ports stay closed to everyone else.
  evaGlobalTcpPorts = lib.sort lib.lessThan eva.networking.firewall.allowedTCPPorts;
  evaGlobalUdpPorts = eva.networking.firewall.allowedUDPPorts;
  # The persistent home trash is not purged on a timer.
  evaTrashTimer = eva.systemd.timers.trash-empty.enable;
  muonTrashTimer = muon.systemd.timers.trash-empty.enable;
  # Stopped rootless containers are kept; the rootful prune stays.
  evaUserPodmanPrune = eva.systemd.user.timers.podman-prune.enable;
}
