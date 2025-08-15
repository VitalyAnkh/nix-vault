# Persistence configuration for additional users on muon machine
{
  # Persistence directories for additional users
  users = {
    xwu = {
      commonMountOptions = [
        "x-gvfs-hide"
      ];
      directories = [
        # Basic XDG directories
        "Downloads"
        "Documents"
        "Pictures"
        "Videos"
        "Music"
        "Desktop"

        # Work directories
        "projects"
        "workspace"
        "tmp"

        # Config and cache
        ".cache"
        ".config"
        ".local"

        # Security
        {
          directory = ".ssh";
          mode = "0700";
        }
        {
          directory = ".gnupg";
          mode = "0700";
        }
      ];
    };

    cxu = {
      commonMountOptions = [
        "x-gvfs-hide"
      ];
      directories = [
        # Basic XDG directories
        "Downloads"
        "Documents"
        "Pictures"
        "Videos"
        "Music"
        "Desktop"

        # Work directories
        "projects"
        "workspace"
        "tmp"

        # Config and cache
        ".cache"
        ".config"
        ".local"

        # Security
        {
          directory = ".ssh";
          mode = "0700";
        }
        {
          directory = ".gnupg";
          mode = "0700";
        }
      ];
    };

    zzhou = {
      commonMountOptions = [
        "x-gvfs-hide"
      ];
      directories = [
        # Basic XDG directories
        "Downloads"
        "Documents"
        "Pictures"
        "Videos"
        "Music"
        "Desktop"

        # Work directories
        "projects"
        "workspace"
        "tmp"

        # Config and cache
        ".cache"
        ".config"
        ".local"

        # Security
        {
          directory = ".ssh";
          mode = "0700";
        }
        {
          directory = ".gnupg";
          mode = "0700";
        }
      ];
    };
  };

  # Systemd tmpfiles configuration for additional users
  tmpfiles =
    let
      userPermission = user: {
        user = user;
        group = "users";
        mode = "0755";
      };
    in
    {
      "/home/xwu/.config".d = userPermission "xwu";
      "/home/xwu/.cache".d = userPermission "xwu";
      "/home/xwu/.local".d = userPermission "xwu";
      "/home/xwu/.local/share".d = userPermission "xwu";
      "/home/xwu/.local/state".d = userPermission "xwu";

      "/home/cxu/.config".d = userPermission "cxu";
      "/home/cxu/.cache".d = userPermission "cxu";
      "/home/cxu/.local".d = userPermission "cxu";
      "/home/cxu/.local/share".d = userPermission "cxu";
      "/home/cxu/.local/state".d = userPermission "cxu";

      "/home/zzhou/.config".d = userPermission "zzhou";
      "/home/zzhou/.cache".d = userPermission "zzhou";
      "/home/zzhou/.local".d = userPermission "zzhou";
      "/home/zzhou/.local/share".d = userPermission "zzhou";
      "/home/zzhou/.local/state".d = userPermission "zzhou";
    };
}
