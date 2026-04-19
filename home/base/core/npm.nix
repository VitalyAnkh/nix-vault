{ config, ... }:
{
  # 1. make `npm install -g <pkg>` happey
  # 2. require a short release-age delay for registry packages
  home.file.".npmrc".text = ''
    prefix=${config.home.homeDirectory}/.npm
    min-release-age=7
  '';
}
