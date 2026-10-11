{
  # Keep the daemon log where the Nix installer's daemon wrote it. This applies only
  # when nix-darwin manages Nix (nix.enable).
  services.nix-daemon.logFile = "/var/log/nix-daemon.log";
}
