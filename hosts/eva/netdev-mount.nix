{
  config,
  lib,
  myvars,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkDefault
    mkIf
    mkOption
    types
    ;

  cfg = config.vr.hosts.eva.webdav;
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

    uid = mkOption {
      type = types.nullOr types.ints.unsigned;
      default =
        let
          user = config.users.users.${myvars.username} or { };
        in
        user.uid or null;
      description = ''
        Local uid that should own the mounted WebDAV files.

        When WebDAV is enabled and the user does not have a statically known
        uid at eval time, eva falls back to vitalyr's current uid, 1000. Set
        this explicitly to override that fallback.
      '';
    };

    gid = mkOption {
      type = types.nullOr types.ints.unsigned;
      default =
        let
          user = config.users.users.${myvars.username} or { };
          primaryGroupName = if (user.group or null) != null then user.group else "users";
          primaryGroup = config.users.groups.${primaryGroupName} or { };
        in
        if (primaryGroup.gid or null) != null then
          primaryGroup.gid
        else if primaryGroupName == "users" then
          100
        else
          null;
      description = ''
        Local gid that should own the mounted WebDAV files.

        When WebDAV is enabled and the primary group does not have a
        statically known gid at eval time, eva falls back to vitalyr's current
        primary gid, 100. Set this explicitly to override that fallback.
      '';
    };
  };

  config = {
    vr.hosts.eva.webdav =
      let
        user = config.users.users.${myvars.username} or { };
        primaryGroupName = if (user.group or null) != null then user.group else "users";
        primaryGroup = config.users.groups.${primaryGroupName} or { };
      in
      mkIf cfg.enable {
        # Keep the optional mount owned by the primary desktop user on eva.
        # Prefer statically configured ids when available, otherwise fall back
        # to eva's current `vitalyr` uid/gid.
        uid = mkDefault (if (user.uid or null) != null then user.uid else 1000);
        gid = mkDefault (if (primaryGroup.gid or null) != null then primaryGroup.gid else 100);
      };

    # supported file systems, so we can mount removable/network volumes that use them
    boot.supportedFilesystems = [
      # "cifs"
      "davfs"
    ];

    assertions =
      lib.optional cfg.enable {
        assertion = config ? age && builtins.hasAttr cfg.credentialsSecret (config.age.secrets or { });
        message = "eva WebDAV mount requires age secret `${cfg.credentialsSecret}`.";
      }
      ++ lib.optional cfg.enable {
        assertion = cfg.uid != null;
        message = ''
          eva WebDAV mount requires a non-null uid. Set
          `vr.hosts.eva.webdav.uid` explicitly or assign
          `users.users.${myvars.username}.uid`.
        '';
      }
      ++ lib.optional cfg.enable {
        assertion = cfg.gid != null;
        message =
          let
            user = config.users.users.${myvars.username} or { };
            primaryGroupName = if (user.group or null) != null then user.group else "users";
          in
          ''
            eva WebDAV mount requires a non-null gid for primary group
            `${primaryGroupName}`. Set `vr.hosts.eva.webdav.gid` explicitly or
            assign `users.groups.${primaryGroupName}.gid`.
          '';
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
          "uid=${toString cfg.uid},gid=${toString cfg.gid},dir_mode=0750,file_mode=0750"
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
    #     "uid=${toString cfg.uid},gid=${toString cfg.gid},dir_mode=0755,file_mode=0755"
    #     "vers=3.0,credentials=${config.age.secrets.smb-credentials.path}"
    #   ];
    # };
  };
}
