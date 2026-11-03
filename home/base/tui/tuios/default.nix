{
  config,
  myvars,
  pkgs,
  ...
}:
let
  # tuios watches config.toml and its settings page writes it back, so link the
  # checked-in file out-of-store instead of into the store.
  configDir = "${myvars.repoRoot or "${config.home.homeDirectory}/nix-vault"}/home/base/tui/tuios";
in
{
  home.packages = [ pkgs.tuios ];

  xdg.configFile."tuios/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${configDir}/config.toml";

  # Upstream auto-starts tuios in every interactive nushell. Not here: the
  # zellij setup tuios replaces did not start on its own either, so run `tuios`
  # when needed.
  programs.nushell.extraConfig = ''
    # TUIOS keeps TERM=xterm-256color for terminfo compatibility, but it forwards
    # the Kitty graphics protocol that kitty and Ghostty speak. Force the guest TERM
    # to xterm-kitty so graphics-aware apps do not disable themselves; its terminfo
    # entry comes with kitty.
    if ("TUIOS_ENV" in $env) {
      $env.TERM = "xterm-kitty"
    }
  '';
}
