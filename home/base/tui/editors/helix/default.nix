{
  config,
  pkgs,
  helix,
  ...
}:

let
  helixPackages = helix.packages.${pkgs.stdenv.hostPlatform.system};
  helixPackage =
    (helixPackages.default.override {
      # Upstream currently includes a bovex grammar revision whose GitHub archive
      # is unavailable. Exclude it from the packaged grammar set so system rebuilds
      # do not depend on that broken source.
      includeGrammarIf = grammar: grammar.name != "bovex";
    }).overrideAttrs
      (prevAttrs: {
        cargoBuildFeatures = prevAttrs.cargoBuildFeatures or [ ] ++ [ "steel" ];
      });
in
{
  # to make steel work, we need to git clone this repo to your home directory.
  home.sessionVariables.HELIX_STEEL_CONFIG = "${config.home.homeDirectory}/nix-config/home/base/tui/editors/helix/steel";

  home.packages = with pkgs; [
    steel
  ];

  programs.helix = {
    enable = true;
    # enable steel as the plugin system
    # https://github.com/helix-editor/helix/pull/8675
    # https://github.com/mattwparas/helix/blob/steel-event-system/STEEL.md
    package = helixPackage;
    settings = {
      editor = {
        line-number = "relative";
        cursorline = true;
        color-modes = true;
        lsp.display-messages = true;
        cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };
        indent-guides.render = true;
      };
      keys.normal = {
        space = {
          space = "file_picker";
          w = ":w";
          q = ":q";
        };
        esc = [
          "collapse_selection"
          "keep_primary_selection"
        ];
      };
    };
  };
}
