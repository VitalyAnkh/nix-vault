{
  myvars,
  config,
  pkgs,
  ...
}:
{
  # Don't allow mutation of users outside the config.
  users.mutableUsers = false;

  # Root-equivalent / over-broad groups are deliberately NOT added to the
  # user's `extraGroups` below, e.g.:
  #   docker / podman -> rootful container socket (~ root)
  #   libvirtd        -> polkit grants it `org.libvirt.unix.manage` (~ root)
  #   disk            -> raw block devices (~ root)
  #   input           -> keylogging
  # Membership is a *passwordless* path to root, so run those commands with
  # `sudo` instead (e.g. `sudo virsh`). The groups below exist only for the
  # services that need them; `security-container-groups` guards the main ones.
  users.groups = {
    "${myvars.username}" = { };
    podman = { };
    docker = { };
    wireshark = { };
    # for android platform tools's udev rules
    adbusers = { };
    dialout = { };
    # for openocd (embedded system development)
    plugdev = { };
    # shared group for services that read/write the same data directory
    fileshare = { };
  };

  # VR_TODO: move the following line to other places
  programs.fish = {
    enable = true;
    package = pkgs.fish;
    #configFile.source = ./config.nu;
  };

  users.users."${myvars.username}" = {
    # we have to use initialHashedPassword here when using tmpfs for /
    inherit (myvars) initialHashedPassword;
    home = "/home/${myvars.username}";
    isNormalUser = true;
    #shell = pkgs-unstable.fish;
    extraGroups = [
      myvars.username
      "users"
      "wheel"
      "uinput"
      "networkmanager" # for nmtui / nm-connection-editor
      "wireshark"
      "adbusers" # android debugging
      "fileshare"
    ];
  };

  # root's ssh key are mainly used for remote deployment
  users.users.root = {
    inherit (myvars) initialHashedPassword;
    openssh.authorizedKeys.keys = myvars.mainSshAuthorizedKeys ++ myvars.secondaryAuthorizedKeys;
  };
}
