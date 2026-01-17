{
  myvars,
  config,
  lib,
  ...
}:
{
  # Don't allow mutation of users outside the config.
  users.mutableUsers = false;

  users.groups = {
    "${myvars.username}" = { };
    "xwu" = { };
    "cxu" = { };
    "zzhou" = { };
    "sw" = { };
    "jwli" = { };
    "mzhang" = { };
    "jcao" = { };
    "m01005" = { };
    "hazhang" = { };
    docker = { }; # Docker group for muon
    podman = { }; # Keep podman group as well
    wireshark = { };
    # for android platform tools's udev rules
    adbusers = { };
    dialout = { };
    # for openocd (embedded system development)
    plugdev = { };
    # misc
    uinput = { };
  };

  # Main user (existing user)
  users.users."${myvars.username}" = {
    inherit (myvars) initialHashedPassword;
    home = "/home/${myvars.username}";
    isNormalUser = true;
    extraGroups = [
      myvars.username
      "users"
      "networkmanager"
      "wheel"
      "docker" # Added docker group
      "podman" # Keep podman group as well
      "wireshark"
      "adbusers"
      "libvirtd"
    ];
  };

  # Additional user: xwu (only on muon machine)
  users.users.xwu = {
    initialHashedPassword = "$7$GU..../....RO9QNYSmcMtIotbxT5gxE.$fPT6iOEqj/QiIRxO7yOwiB4pqjEPfcAaQblpQdolG61";
    home = "/home/xwu";
    isNormalUser = true;
    description = "Xwu User";
    extraGroups = [
      "xwu"
      "users"
      "networkmanager"
      "wheel"
      "docker" # Added docker group
      "podman" # Keep podman group as well
    ];
  };

  users.users.hazhang = {
    initialHashedPassword = "$7$GU..../....qxODrBd6YQiILq340sMF40$uBnsu.QY93NZammMesaxofXLl11Hx3/KEXFbAdxiEX6";
    home = "/home/hazhang";
    isNormalUser = true;
    description = "hazhang user";
    extraGroups = [
      "hazhang"
      "users"
      "networkmanager"
      "wheel"
      "docker" # Added docker group
      "podman" # Keep podman group as well
    ];
  };

  # Additional user: cxu (only on muon machine)
  users.users.cxu = {
    initialHashedPassword = "$6$P1KoOQSCl5amV1TR$3Bs9yJSbZ4wkfEcwVDq7IwqEBwBJk3A7gETqoMo5l1oFVQaKZM5GiaDqE2vUNrOs5qXLVNWzkzrc3lDmYWh2d0";
    home = "/home/cxu";
    isNormalUser = true;
    description = "Cxu User";
    extraGroups = [
      "cxu"
      "users"
      "networkmanager"
      "wheel"
      "docker" # Added docker group
      "podman" # Keep podman group as well
    ];
  };

  # Additional user: zzhou (only on muon machine)
  users.users.zzhou = {
    initialHashedPassword = "$6$P1KoOQSCl5amV1TR$3Bs9yJSbZ4wkfEcwVDq7IwqEBwBJk3A7gETqoMo5l1oFVQaKZM5GiaDqE2vUNrOs5qXLVNWzkzrc3lDmYWh2d0";
    home = "/home/zzhou";
    isNormalUser = true;
    description = "zzhou User";
    extraGroups = [
      "zzhou"
      "users"
      "networkmanager"
      "wheel"
      "docker" # Added docker group
      "podman" # Keep podman group as well
    ];
  };

  # Additional user: sw (only on muon machine)
  users.users.sw = {
    initialHashedPassword = "$6$P1KoOQSCl5amV1TR$3Bs9yJSbZ4wkfEcwVDq7IwqEBwBJk3A7gETqoMo5l1oFVQaKZM5GiaDqE2vUNrOs5qXLVNWzkzrc3lDmYWh2d0";
    home = "/home/sw";
    isNormalUser = true;
    description = "sw";
    extraGroups = [
      "sw"
      "users"
      "networkmanager"
      "wheel"
      "docker" # Added docker group
      "podman" # Keep podman group as well
    ];
  };

  # Additional user: jwli (only on muon machine)
  users.users.jwli = {
    initialHashedPassword = "$6$P1KoOQSCl5amV1TR$3Bs9yJSbZ4wkfEcwVDq7IwqEBwBJk3A7gETqoMo5l1oFVQaKZM5GiaDqE2vUNrOs5qXLVNWzkzrc3lDmYWh2d0";
    home = "/home/jwli";
    isNormalUser = true;
    description = "jwli User";
    extraGroups = [
      "jwli"
      "users"
      "networkmanager"
      "wheel"
      "docker" # Added docker group
      "podman" # Keep podman group as well
    ];
  };

  # Additional user: mzhang (only on muon machine)
  users.users.mzhang = {
    initialHashedPassword = "$6$P1KoOQSCl5amV1TR$3Bs9yJSbZ4wkfEcwVDq7IwqEBwBJk3A7gETqoMo5l1oFVQaKZM5GiaDqE2vUNrOs5qXLVNWzkzrc3lDmYWh2d0";
    home = "/home/mzhang";
    isNormalUser = true;
    description = "mzhang User";
    extraGroups = [
      "mzhang"
      "users"
      "networkmanager"
      "wheel"
      "docker" # Added docker group
      "podman" # Keep podman group as well
    ];
  };

  # Additional user: jcao (only on muon machine)
  users.users.jcao = {
    initialHashedPassword = "$6$P1KoOQSCl5amV1TR$3Bs9yJSbZ4wkfEcwVDq7IwqEBwBJk3A7gETqoMo5l1oFVQaKZM5GiaDqE2vUNrOs5qXLVNWzkzrc3lDmYWh2d0";
    home = "/home/jcao";
    isNormalUser = true;
    description = "jcao User";
    extraGroups = [
      "jcao"
      "users"
      "networkmanager"
      "wheel"
      "docker" # Added docker group
      "podman" # Keep podman group as well
    ];
  };

  # Additional user: m01005 (only on muon machine)
  users.users.m01005 = {
    initialHashedPassword = "$6$P1KoOQSCl5amV1TR$3Bs9yJSbZ4wkfEcwVDq7IwqEBwBJk3A7gETqoMo5l1oFVQaKZM5GiaDqE2vUNrOs5qXLVNWzkzrc3lDmYWh2d0";
    home = "/home/m01005";
    isNormalUser = true;
    description = "m01005 User";
    extraGroups = [
      "m01005"
      "users"
      "networkmanager"
      "wheel"
      "docker" # Added docker group
      "podman" # Keep podman group as well
    ];
  };

  # root's ssh key are mainly used for remote deployment
  users.users.root = {
    inherit (myvars) initialHashedPassword;
    openssh.authorizedKeys.keys = myvars.mainSshAuthorizedKeys ++ myvars.secondaryAuthorizedKeys;
  };
}
