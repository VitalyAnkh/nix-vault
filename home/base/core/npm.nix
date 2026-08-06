{ config, ... }:
{
  # make `npm install -g <pkg>` happy without blocking fresh registry releases
  home.file.".npmrc".text = ''
    prefix=${config.home.homeDirectory}/.npm
    min-release-age=0
  '';

  # pnpm v11 reads non-auth settings from its YAML config, not from .npmrc.
  # Keep the established global package layout, so a pnpm v11 upgrade does not
  # try to relink existing global packages from a different virtual store.
  home.file.".config/pnpm/config.yaml".text = ''
    globalDir: ${config.xdg.dataHome}/pnpm/global
    globalBinDir: ${config.xdg.dataHome}/pnpm/bin
    virtualStoreDir: node_modules/.pnpm
    minimumReleaseAge: 0
    fetchTimeout: 300000
    fetchRetries: 5
    networkConcurrency: 2
  '';
}
