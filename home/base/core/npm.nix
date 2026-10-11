{ config, lib, ... }:
let
  cfg = config.modules;
in
{
  options.modules = {
    npm.prefix = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.npm";
      defaultText = lib.literalExpression ''"''${config.home.homeDirectory}/.npm"'';
      description = "Prefix for `npm install -g`; its bin directory holds the commands.";
    };
    pnpm = {
      globalDir = lib.mkOption {
        type = lib.types.str;
        default = "${config.xdg.dataHome}/pnpm/global";
        defaultText = lib.literalExpression ''"''${config.xdg.dataHome}/pnpm/global"'';
        description = "Directory of pnpm's global packages.";
      };
      globalBinDir = lib.mkOption {
        type = lib.types.str;
        default = "${config.xdg.dataHome}/pnpm/bin";
        defaultText = lib.literalExpression ''"''${config.xdg.dataHome}/pnpm/bin"'';
        description = "Directory of the commands of pnpm's global packages.";
      };
      storeDir = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "pnpm's content-addressable store; null keeps pnpm's default.";
      };
      virtualStoreDir = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "node_modules/.pnpm";
        description = "pnpm's virtual store directory; null keeps pnpm's default.";
      };
    };
  };

  config = {
    # make `npm install -g <pkg>` happy without blocking fresh registry releases
    home.file.".npmrc".text = ''
      prefix=${cfg.npm.prefix}
      min-release-age=0
    '';

    # pnpm v11 reads non-auth settings from its YAML config, not from .npmrc.
    # Keep the established global package layout, so a pnpm v11 upgrade does not
    # try to relink existing global packages from a different virtual store.
    home.file.".config/pnpm/config.yaml".text = lib.concatLines (
      [
        "globalDir: ${cfg.pnpm.globalDir}"
        "globalBinDir: ${cfg.pnpm.globalBinDir}"
      ]
      ++ lib.optional (cfg.pnpm.storeDir != null) "storeDir: ${cfg.pnpm.storeDir}"
      ++ lib.optional (cfg.pnpm.virtualStoreDir != null) "virtualStoreDir: ${cfg.pnpm.virtualStoreDir}"
      ++ [
        "minimumReleaseAge: 0"
        "fetchTimeout: 300000"
        "fetchRetries: 5"
        "networkConcurrency: 2"
      ]
    );
  };
}
