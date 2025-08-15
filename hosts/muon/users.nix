{
  myvars,
  config,
  pkgs-unstable,
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
    podman = { };
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
      "podman"
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
      "podman"
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
      "podman"
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
      "podman"
    ];
  };

  # root's ssh key are mainly used for remote deployment
  users.users.root = {
    inherit (myvars) initialHashedPassword;
    openssh.authorizedKeys.keys = myvars.mainSshAuthorizedKeys ++ myvars.secondaryAuthorizedKeys;
  };
}
