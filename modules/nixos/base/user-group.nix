{
  myvars,
  config,
  pkgs-unstable,
  ...
}: {
  # Don't allow mutation of users outside the config.
  users.mutableUsers = false;

  users.groups = {
    "${myvars.username}" = {};
    docker = {};
    wireshark = {};
    # for android platform tools's udev rules
    adbusers = {};
    dialout = {};
    # for openocd (embedded system development)
    plugdev = {};
    # misc
    uinput = {};
  };

  # VR_TODO: move the following line to other places
  programs.fish = {
    enable = true;
    package = pkgs-unstable.fish;
    #configFile.source = ./config.nu;
  };

  users.users."${myvars.username}" = {
    # generated by `mkpasswd -m scrypt`
    # we have to use initialHashedPassword here when using tmpfs for /
    inherit (myvars) initialHashedPassword;
    home = "/home/${myvars.username}";
    isNormalUser = true;
    #shell = pkgs-unstable.fish;
    extraGroups = [
      myvars.username
      "users"
      "networkmanager"
      "wheel"
      "docker"
      "wireshark"
      "adbusers"
      "libvirtd"
    ];
  };

  # root's ssh key are mainly used for remote deployment
  users.users.root = {
    initialHashedPassword = config.users.users."${myvars.username}".initialHashedPassword;
    openssh.authorizedKeys.keys = config.users.users."${myvars.username}".openssh.authorizedKeys.keys;
  };
}
