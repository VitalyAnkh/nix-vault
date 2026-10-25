{
  config,
  lib,
  pkgs,
  mysecrets,
  myvars,
  ...
}:
let
  cfg = config.modules.ssh.personalConfig;
  sshConfigRegularFile = pkgs.stdenv.hostPlatform.isLinux && config.programs.ssh.enable;

  # WA-035: settings for the home LAN, which the desktop reaches over a Mesh
  # WiFi backhaul.
  lanHost = {
    # A lost first SYN must not fail the connection; a LAN handshake is ~2 ms,
    # so the connect is cut short and retried instead of hanging.
    ConnectTimeout = 1;
    ConnectionAttempts = 3;
    # One persistent master per host keeps a session (and with it the mesh's
    # forwarding entry for that peer) open, so later connections reuse it
    # instead of resolving and handshaking again. Three missed keepalives reap a
    # master whose path died.
    ControlMaster = "auto";
    ControlPersist = "30m";
    ServerAliveInterval = 15;
  };
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
    # Keep this one definition: Nix merges a `settings."<pattern>"` attribute
    # path into `settings = ...` only while that value stays an attrset literal,
    # so the generated LAN patterns are merged inside it with `//` instead.
    settings = {
      "*" = {
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

      "github.com" = lib.mkIf cfg.enable {
        # avoid clash fake-IP6 hang, see hosts/eva/proxy.nix
        AddressFamily = "inet";
        HostName = "ssh.github.com";
        Port = 443;
        User = "git";
        IdentitiesOnly = true;
      };

      "192.168.*" = lib.mkIf cfg.enable (
        {
          ForwardAgent = true;
        }
        // lanHost
      );
    }
    // lib.genAttrs (builtins.attrNames myvars.networking.hostsAddr) (_: lib.mkIf cfg.enable lanHost);
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
