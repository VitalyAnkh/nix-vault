{ config, lib, ... }:
{
  # Configure Podman storage options for system-wide shared storage
  virtualisation.containers.storage.settings = {
    storage = {
      driver = "overlay";
      runroot = "/run/containers/storage";
      graphroot = "/var/lib/containers/storage";
      options.overlay.mountopt = "nodev,metacopy=on";
    };
  };

  # Configure container registries using NixOS options
  virtualisation.containers.registries = {
    search = [
      "docker.io"
      "quay.io"
      "gcr.io"
    ];
    insecure = [ ];
    block = [ ];
  };

  # Enable podman socket for system-wide daemon
  systemd.sockets.podman = {
    enable = true;
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "/run/podman/podman.sock" ];
  };

  # Create symlink for docker compatibility
  systemd.tmpfiles.rules = [
    "L+ /var/run/docker.sock - - - - /run/podman/podman.sock"
  ];
}
