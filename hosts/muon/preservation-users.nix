{
  myvars,
  preservation,
  pkgs,
  ...
}:
let
  inherit (myvars) username;

  # Extra users on muon that should share the same preservation profile as ${username}
  additionalUsers = [
    "xwu"
    "cxu"
    "zzhou"
    "m01537"
    "george"
    "sw"
    "jwli"
    "mzhang"
    "jcao"
    "m01005"
    "hazhang"
    "hwtest"
  ];

  # Shared preservation profile for ${username}, as defined by the host's
  # preservation.nix (muon imports hosts/eva/preservation.nix).
  # We re-evaluate that module here to avoid duplicating the directory list.
  evaPreservationConfig = import ../eva/preservation.nix {
    inherit preservation pkgs myvars;
  };

  baseUserPreservation =
    evaPreservationConfig.preservation.preserveAt."/persistent".users.${username};

  userPermission = user: {
    user = user;
    group = "users";
    mode = "0755";
  };

  userHomePermission =
    user:
    userPermission user
    // {
      mode = "0700";
    };

  tmpfilePaths = [
    ".config"
    ".cache"
    ".local"
    ".local/share"
    ".local/state"
    ".local/state/nix"
    ".terraform.d"
  ];

  mkUserAttr = name: {
    inherit name;
    value = baseUserPreservation;
  };

  mkTmpfileAttr = user: path: {
    name = "/home/${user}/${path}";
    value = {
      d = userPermission user;
    };
  };

  mkHomeTmpfileAttr = user: {
    name = "/home/${user}";
    value = {
      d = userHomePermission user;
    };
  };

  perUserTmpfiles =
    user: [ (mkHomeTmpfileAttr user) ] ++ (builtins.map (path: mkTmpfileAttr user path) tmpfilePaths);

  allTmpfiles = builtins.concatMap perUserTmpfiles additionalUsers;
in
{
  config = {
    # Give all additional users the same preservation profile as ${username}
    preservation.preserveAt."/persistent".users = builtins.listToAttrs (
      builtins.map mkUserAttr additionalUsers
    );

    # Ensure their ~/.config, ~/.cache, etc. have correct ownership/permissions
    systemd.tmpfiles.settings.preservation = builtins.listToAttrs allTmpfiles;
  };
}
