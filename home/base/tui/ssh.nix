{
  config,
  lib,
  mysecrets,
  ...
}:
let
  cfg = config.modules.ssh.personalConfig;
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
        # avoid mihomo fake-IP6 hangs; the native service keeps SSH on IPv4 when needed
        AddressFamily = "inet";
        HostName = "ssh.github.com";
        Port = 443;
        User = "git";
        IdentitiesOnly = true;
      };

      "192.168.*" = lib.mkIf cfg.enable {
        ForwardAgent = true;
        IdentityFile = "/etc/agenix/ssh-key-romantic";
        IdentitiesOnly = true;
      };
    };
  };
}
