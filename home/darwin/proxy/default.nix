{
  config,
  lib,
  myvars,
  pkgs,
  ...
}:
let
  repoRoot = myvars.repoRoot or "${config.home.homeDirectory}/nix-config";
in
{
  options.modules.desktop.proxy.enable =
    lib.mkEnableOption "the repository's proxy configuration"
    // {
      default = true;
    };

  config = lib.mkIf config.modules.desktop.proxy.enable {
    home.packages = with pkgs; [
      clash-meta
    ];

    home.file.".proxychains/proxychains.conf".source =
      config.lib.file.mkOutOfStoreSymlink "${repoRoot}/home/darwin/proxy/proxychains.conf";
  };
}
