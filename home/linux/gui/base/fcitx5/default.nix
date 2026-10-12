{
  config,
  myvars,
  pkgs,
  ...
}:
let
  repoRoot = myvars.repoRoot or "${config.home.homeDirectory}/nix-vault";
in
{
  # The local profile and Rime data are authoritative for this host family.
  # Keep Catppuccin from rewriting the generated fcitx5 configuration.
  catppuccin.fcitx5.enable = false;
  xdg.configFile = {
    "fcitx5/profile" = {
      source = ./profile;
      # every time fcitx5 switch input method, it will modify ~/.config/fcitx5/profile,
      # so we need to force replace it in every rebuild to avoid file conflict.
      force = true;
    };
    "fcitx5/config" = {
      source = ./config;
      force = true;
    };
    "fcitx5/conf/pinyin.conf" = {
      source = ./pinyin.conf;
      force = true;
    };
    "fcitx5/conf/cloudpinyin.conf" = {
      source = ./cloudpinyin.conf;
      force = true;
    };
    # Keep the user-managed Mozc dictionary database outside the store.
    "mozc/config1.db".source =
      config.lib.file.mkOutOfStoreSymlink "${repoRoot}/home/linux/gui/base/fcitx5/mozc-config1.db";
  };

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      # needed enable rime using configtool after installed
      qt6Packages.fcitx5-configtool
      qt6Packages.fcitx5-chinese-addons
      # fcitx5-mozc    # japanese input method
      fcitx5-gtk # gtk im module

      # Chinese: the flypy (小鹤音形) fcitx5-rime addon is wired in
      # home/base/gui/rime/default.nix, which is also where the rime-data-flypy
      # package is resolved. fcitx5-chinese-addons is not used.

      # Japanese
      # ctrl-i / F7 - convert to takakana
      # ctrl-u / F6 - convert to hiragana
      fcitx5-mozc-ut # Moze with UT dictionary

      # Korean
      fcitx5-hangul
    ];
  };
}
