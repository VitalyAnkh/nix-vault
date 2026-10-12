{
  config,
  myvars,
  pkgs,
  tuios,
  ...
}:
let
  # nixpkgs lags behind upstream; use the flake input.
  tuiosPkg = tuios.packages.${pkgs.stdenv.hostPlatform.system}.tuios;

  # tuios watches config.toml and its settings page writes it back, so link the
  # checked-in file out-of-store instead of into the store.
  configDir = "${myvars.repoRoot or "${config.home.homeDirectory}/nix-vault"}/home/base/tui/tuios";
in
{
  home.packages = [ tuiosPkg ];

  xdg.configFile."tuios/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${configDir}/config.toml";

  # Upstream auto-starts tuios in every interactive nushell. Not here: the
  # zellij setup tuios replaces did not start on its own either, so run `tuios`
  # when needed.
}
