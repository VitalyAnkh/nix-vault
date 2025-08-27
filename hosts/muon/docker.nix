{ lib, ... }:
{
  # Override the desktop virtualisation module settings for muon
  # Use real Docker instead of Podman with docker compatibility
  
  virtualisation = {
    # Enable real Docker
    docker = {
      enable = lib.mkForce true;
      # Enable rootless docker for better security (optional)
      rootless = {
        enable = true;
        setSocketVariable = true;
      };
      # Do NOT auto prune as requested
      autoPrune.enable = false;
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
}