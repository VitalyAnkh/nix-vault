{
  config,
  lib,
  myvars,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.vr.hosts.eva.webdav;

  mountUid = toString (config.users.users.${myvars.username}.uid or 1000);
  mountGid = toString (config.users.groups.users.gid or 100);
in
{
  options.vr.hosts.eva.webdav = {
    enable = mkEnableOption "the optional idols-ai-style WebDAV mount on eva";

    mountPoint = mkOption {
      type = types.str;
      default = "/mnt/fileshare";
      description = "Mount point for eva's optional WebDAV share.";
    };

    url = mkOption {
      type = types.str;
      default = "https://webdav.writefor.fun/";
      description = "Remote WebDAV endpoint used by eva when the mount is enabled.";
    };

    credentialsSecret = mkOption {
      type = types.str;
      default = "davfs-secrets";
      description = "Name of the agenix secret that should populate /etc/davfs2/secrets.";
    };
  };

  config = {
    # supported file systems, so we can mount removable/network volumes that use them
    boot.supportedFilesystems = [
      # "cifs"
      "davfs"
    ];

    assertions = lib.optional cfg.enable {
      assertion = config ? age && builtins.hasAttr cfg.credentialsSecret (config.age.secrets or { });
      message = "eva WebDAV mount requires age secret `${cfg.credentialsSecret}`.";
    };

    services.davfs2 = mkIf cfg.enable {
      enable = true;
      # https://man.archlinux.org/man/davfs2.conf.5
      settings = {
        globalSection.use_locks = true;
        sections."${cfg.mountPoint}" = {
          # Fetch directory metadata in larger batches to reduce round-trips.
          gui_optimize = true;
        };
      };
    };

    fileSystems = mkIf cfg.enable {
      "${cfg.mountPoint}" = {
        device = cfg.url;
        fsType = "davfs";
        options = [
          "nofail"
          "_netdev"
          "rw"
          "uid=${mountUid},gid=${mountGid},dir_mode=0750,file_mode=0750"
        ];
      };
    };

    # davfs2 reads its credentials from /etc/davfs2/secrets.
    environment.etc."davfs2/secrets" = mkIf cfg.enable {
      source = config.age.secrets.${cfg.credentialsSecret}.path;
      mode = "0600";
    };

    # Example smb/cifs mount:
    # fileSystems."/home/${myvars.username}/SMB-Downloads" = {
    #   device = "//windows-server-nas/Downloads";
    #   fsType = "cifs";
    #   options = [
    #     "nofail"
    #     "_netdev"
    #     "uid=${mountUid},gid=${mountGid},dir_mode=0755,file_mode=0755"
    #     "vers=3.0,credentials=${config.age.secrets.smb-credentials.path}"
    #   ];
    # };
  };
}
