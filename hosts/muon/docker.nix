{
  lib,
  config,
  pkgs,
  ...
}:
{
  # Override the desktop virtualisation module settings for muon
  # Use real Docker in daemon mode for multi-user image sharing

  virtualisation = {
    # Enable real Docker in daemon mode (not rootless) for image sharing
    docker = {
      enable = lib.mkForce true;

      # Disable rootless mode to use system-wide daemon for image sharing
      rootless = {
        enable = lib.mkForce false;
        setSocketVariable = false;
      };

      # Configure Docker daemon settings
      daemon.settings = {
        # Store Docker data in persistent location
        data-root = "/var/lib/docker";

        # Enable live restore to keep containers running during daemon restarts
        live-restore = true;

        # Set storage driver to overlay2 for better performance
        storage-driver = "overlay2";

        # Use default journald log driver (without log-opts as they're not supported)
        # Journald will manage log rotation automatically
      };

      # Do NOT auto prune as requested
      autoPrune.enable = false;

      # Enable Docker service to start on boot
      enableOnBoot = true;
    };

    # Explicitly disable podman and its docker compatibility
    podman = {
      enable = lib.mkForce false;
      dockerCompat = lib.mkForce false;
    };

    # Keep oci-containers backend as docker
    oci-containers = {
      backend = lib.mkForce "docker";
    };
  };

  # Users are already added to docker group in users.nix
  # No need to duplicate the configuration here

  # Ensure Docker socket has correct permissions
  systemd.services.docker = {
    serviceConfig = {
      # Ensure the service can write to persistent storage
      ReadWritePaths = [ "/var/lib/docker" ];
    };
  };
}
