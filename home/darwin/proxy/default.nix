{
  config,
  lib,
  myvars,
  pkgs,
  ...
}:
let
  repoRoot = myvars.repoRoot or "${config.home.homeDirectory}/nix-vault";
  configDir = "${config.home.homeDirectory}/.config/mihomo";
  configFile = "${configDir}/config.yaml";
in
{
  options.modules.desktop.proxy.enable =
    lib.mkEnableOption "the repository's proxy configuration"
    // {
      default = true;
    };

  config = lib.mkIf config.modules.desktop.proxy.enable {
    # Mihomo is the maintained Clash-compatible core. Keep its config outside
    # the store because subscriptions and controller credentials are private.
    home.packages = [ pkgs.mihomo ];

    home.file.".proxychains/proxychains.conf".source =
      config.lib.file.mkOutOfStoreSymlink "${repoRoot}/home/darwin/proxy/proxychains.conf";

    # Start the core only after the user has generated a config. A missing
    # optional proxy must not make a Darwin activation or login fail.
    launchd.enable = true;
    launchd.agents.mihomo = {
      enable = true;
      config = {
        ProgramArguments = [
          "${pkgs.bash}/bin/bash"
          "-lc"
          "if [ -r '${configFile}' ]; then exec ${pkgs.mihomo}/bin/mihomo -d '${configDir}' -f '${configFile}'; fi"
        ];
        RunAtLoad = true;
        KeepAlive = false;
        WatchPaths = [ configFile ];
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/mihomo.stdout.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/mihomo.stderr.log";
      };
    };
  };
}
