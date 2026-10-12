{
  config,
  lib,
  pkgs,
  mysecrets,
  ...
}:
let
  cfg = config.modules.ssh.personalConfig;
  sshConfigRegularFile = pkgs.stdenv.hostPlatform.isLinux && config.programs.ssh.enable;
in
{
  options.modules.ssh.personalConfig.enable =
    lib.mkEnableOption "the repository's personal SSH identities and hosts"
    // {
      default = true;
    };

  config.home.file.".ssh/romantic.pub" = lib.mkIf cfg.enable {
    source = "${mysecrets}/public/romantic.pub";
  };

  config.programs.ssh = {
    # Hosts keeping ~/.ssh/config user-managed can disable this shared config.
    enable = lib.mkDefault true;

    enableDefaultConfig = false;
    settings."*" = {
      ForwardAgent = false;
      AddKeysToAgent = "yes";
      Compression = true;
      ServerAliveInterval = 0;
      ServerAliveCountMax = 3;
      HashKnownHosts = false;
      UserKnownHostsFile = "~/.ssh/known_hosts";
      ControlMaster = "no";
      ControlPath = "~/.ssh/master-%r@%n:%p";
      ControlPersist = "no";
    };

    settings = {
      "github.com" = lib.mkIf cfg.enable {
        # avoid clash fake-IP6 hang, see hosts/eva/proxy.nix
        AddressFamily = "inet";
        HostName = "ssh.github.com";
        Port = 443;
        User = "git";
        IdentitiesOnly = true;
      };

      "192.168.*" = lib.mkIf cfg.enable {
        ForwardAgent = true;
        # decrypted secret: AI agents must not read it
        IdentityFile = "/etc/agenix/ssh-key-romantic";
        IdentitiesOnly = true;
      };
    };
  };

  # Keep ~/.ssh/config a real, user-owned file rather than a /nix/store symlink.
  #
  # OpenSSH accepts a config owned by root or the invoking user, but
  # bubblewrap-based sandboxes (`--unshare-user`) expose root-owned store files
  # as `nobody`, which trips the check (`Bad owner or permissions`).  Disabling
  # the home.file entry keeps Home Manager's linker out of the way; `install`
  # writes a fresh 0600 copy on each activation.
  #
  # Linux only: macOS' Seatbelt sandbox keeps store ownership intact, so the
  # normal symlink is fine there. Hosts that disable the shared config have no
  # generated file to copy.
  # The condition wraps the entry: a leaf-level mkIf would still declare a
  # ".ssh/config" entry, which has no source when the shared config is off.
  config.home.file.".ssh/config" = lib.mkIf sshConfigRegularFile { enable = false; };
  config.home.activation.sshConfigRegularFile = lib.mkIf sshConfigRegularFile (
    lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run install -D -m 600 ${config.home.file.".ssh/config".source} "$HOME/.ssh/config"
    ''
  );
}
