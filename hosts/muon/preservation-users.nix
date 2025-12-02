{
  config,
  lib,
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
    "sw"
    "jwli"
    "mzhang"
    "jcao"
    "m01005"
    "hazhang"
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

  allTmpfiles = builtins.concatMap (
    user: builtins.map (path: mkTmpfileAttr user path) tmpfilePaths
  ) additionalUsers;
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
