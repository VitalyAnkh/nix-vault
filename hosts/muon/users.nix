{
  myvars,
  lib,
  ...
}:
let
  mainUser = myvars.username;

  commonExtraGroups = [
    "users"
    "networkmanager"
    "wheel"
    "docker"
    "podman"
  ];

  sharedHashedPassword = "$6$P1KoOQSCl5amV1TR$3Bs9yJSbZ4wkfEcwVDq7IwqEBwBJk3A7gETqoMo5l1oFVQaKZM5GiaDqE2vUNrOs5qXLVNWzkzrc3lDmYWh2d0";

  additionalUsers = [
    {
      name = "xwu";
      uid = 1008;
      initialHashedPassword = "$7$GU..../....RO9QNYSmcMtIotbxT5gxE.$fPT6iOEqj/QiIRxO7yOwiB4pqjEPfcAaQblpQdolG61";
      description = "Xwu User";
    }
    {
      name = "hazhang";
      uid = 1001;
      initialHashedPassword = "$7$GU..../....qxODrBd6YQiILq340sMF40$uBnsu.QY93NZammMesaxofXLl11Hx3/KEXFbAdxiEX6";
      description = "hazhang user";
    }
    {
      name = "cxu";
      uid = 1000;
      initialHashedPassword = sharedHashedPassword;
      description = "Cxu User";
    }
    {
      name = "zzhou";
      uid = 1009;
      initialHashedPassword = sharedHashedPassword;
      description = "zzhou User";
    }
    {
      name = "m01537";
      uid = 1011;
      initialHashedPassword = "$6$t9D22ZE.YxkWh3.4$v6V7MuBMbOdhQYKZMzPm8gVlixCdrGZCSsC9REvReF5EYuO1PUzUOHgLRsSCaKjITxcPP5GemXrZ.72PSLib9.";
      description = "m01537 User";
    }
    {
      name = "george";
      uid = 1012;
      initialHashedPassword = "$6$hMtgcYVw.aszyff0$0No32EeRKGAMPgYTBrUBNbPQ3.kREBe5E/ZOf9JTtmf.0nPGgW3zH7Y7pjQcgLGXfLouamoTXVa9D.UPvKX/M.";
      description = "George User";
    }
    {
      name = "hwtest";
      uid = 1010;
      initialHashedPassword = sharedHashedPassword;
      description = "hwtest User";
    }
    {
      name = "sw";
      uid = 1006;
      initialHashedPassword = sharedHashedPassword;
      description = "sw";
    }
    {
      name = "jwli";
      uid = 1003;
      initialHashedPassword = sharedHashedPassword;
      description = "jwli User";
    }
    {
      name = "mzhang";
      uid = 1005;
      initialHashedPassword = sharedHashedPassword;
      description = "mzhang User";
    }
    {
      name = "jcao";
      uid = 1002;
      initialHashedPassword = sharedHashedPassword;
      description = "jcao User";
    }
    {
      name = "m01005";
      uid = 1004;
      initialHashedPassword = sharedHashedPassword;
      description = "m01005 User";
    }
  ];

  additionalUserNames = builtins.map (user: user.name) additionalUsers;

  mkUser = user: {
    inherit (user) uid description;
    inherit (user) initialHashedPassword;

    home = "/home/${user.name}";
    isNormalUser = true;
    extraGroups = [ user.name ] ++ commonExtraGroups;
  };

  mkUserAttr = user: {
    name = user.name;
    value = mkUser user;
  };
in
{
  # Don't allow mutation of users outside the config.
  users.mutableUsers = false;

  users.users = (builtins.listToAttrs (builtins.map mkUserAttr additionalUsers)) // {
    # Main user (existing user)
    "${mainUser}" = {
      inherit (myvars) initialHashedPassword;
      uid = 1007;
      home = "/home/${mainUser}";
      isNormalUser = true;
      extraGroups = [
        mainUser
      ]
      ++ commonExtraGroups
      ++ [
        "uinput"
        "wireshark"
        "adbusers"
        "libvirtd"
      ];
    };

    # root's ssh key are mainly used for remote deployment
    root = {
      inherit (myvars) initialHashedPassword;
      openssh.authorizedKeys.keys = myvars.mainSshAuthorizedKeys ++ myvars.secondaryAuthorizedKeys;
    };
  };

  users.groups = (lib.genAttrs ([ mainUser ] ++ additionalUserNames) (_: { })) // {
    docker = { };
    podman = { };
    wireshark = { };
    adbusers = { }; # android platform-tools udev rules
    dialout = { };
    plugdev = { }; # openocd (embedded development)
  };
}
