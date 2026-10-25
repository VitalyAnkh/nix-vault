{
  config,
  lib,
  catppuccin,
  ...
}:
{
  # https://github.com/catppuccin/nix
  imports = [
    catppuccin.homeModules.catppuccin
  ];

  # catppuccin = {
  #   # The default `enable` value for all available programs.
  #   enable = true;
  #   # one of "latte", "frappe", "macchiato", "mocha"
  #   flavor = "mocha";
  #   # one of "blue", "flamingo", "green", "lavender", "maroon", "mauve", "peach", "pink", "red", "rosewater", "sapphire", "sky", "teal", "yellow"
  #   accent = "pink";
  # };

  # Catppuccin themes Neovim only. `enable` is the global toggle that every port
  # requires; with `autoEnable = false` no other port is enrolled, which also
  # silences catppuccin/nix's warning about auto-enrolling ports.
  catppuccin = {
    enable = true;
    autoEnable = false;
    # The colorscheme of home/base/core/editors/neovim (mocha, transparent).
    nvim.enable = true;
    # home/base/gui/zed-editor.nix enables the Zed port upstream; Zed keeps its
    # own theme here, as before.
    zed.enable = lib.mkForce false;
  };

  # catppuccin/nix inlines the starship port at eval time, so nothing references
  # the build and gc drops it; this keeps it in the home closure. See WA-036.
  home.extraDependencies = lib.optional config.catppuccin.starship.enable config.catppuccin.sources.starship;
}
