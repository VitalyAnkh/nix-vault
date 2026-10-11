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
    # A default, so that hosts keeping ~/.ssh/config user-managed can turn it off.
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
