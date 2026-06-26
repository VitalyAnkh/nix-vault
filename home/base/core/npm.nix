{ config, ... }:
{
  # make `npm install -g <pkg>` happy without blocking fresh registry releases
  home.file.".npmrc".text = ''
    prefix=${config.home.homeDirectory}/.npm
    min-release-age=0
  '';

  # pnpm v11 reads non-auth settings from its YAML config, not from .npmrc.
  home.file.".config/pnpm/config.yaml".text = ''
    minimumReleaseAge: 0
  '';
}
