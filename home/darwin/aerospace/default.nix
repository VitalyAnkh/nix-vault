{
  config,
  lib,
  myvars,
  ...
}:
let
  repoRoot = myvars.repoRoot or "${config.home.homeDirectory}/nix-config";
in
{
  options.modules.desktop.aerospace.enable =
    lib.mkEnableOption "the repository's AeroSpace configuration"
    // {
      default = true;
    };

  config = lib.mkIf config.modules.desktop.aerospace.enable {
    home.file.".aerospace.toml".source =
      config.lib.file.mkOutOfStoreSymlink "${repoRoot}/home/darwin/aerospace/aerospace.toml";
  };
}
