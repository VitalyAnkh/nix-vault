{ config, pkgs, ... }:
{
  xdg.configFile = {
    "fcitx5/profile" = {
      source = ./profile;
      # every time fcitx5 switch input method, it will modify ~/.config/fcitx5/profile,
      # so we need to force replace it in every rebuild to avoid file conflict.
      force = true;
    };
    "mozc/config1.db".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/home/linux/gui/base/fcitx5/mozc-config1.db";
  };

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      # for flypy chinese input method
      fcitx5-rime
      # needed enable rime using configtool after installed
      qt6Packages.fcitx5-configtool
      # fcitx5-mozc    # japanese input method
      fcitx5-gtk # gtk im module

      # Chinese
      # fcitx5-rime # for flypy chinese input method
      qt6Packages.fcitx5-chinese-addons # we use rime instead

      # Japanese
      # ctrl-i / F7 - convert to takakana
      # ctrl-u / F6 - convert to hiragana
      fcitx5-mozc-ut # Moze with UT dictionary

      # Korean
      fcitx5-hangul
    ];
  };
}
