{
  pkgs,
  config,
  lib,
  ...
}:
{
  # If your themes for mouse cursor, icons or windows don’t load correctly,
  # try setting them with home.pointerCursor and gtk.theme,
  # which enable a bunch of compatibility options that should make the themes load in all situations.

  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
  };

  # set dpi for 4k monitor
  xresources.properties = {
    # dpi for Xorg's font
    "Xft.dpi" = 150;
    # or set a generic dpi
    "*.dpi" = 150;
  };

  home.activation.refreshFontconfigCache = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -d "${config.xdg.cacheHome}/fontconfig" ]; then
      run rm -f ${config.xdg.cacheHome}/fontconfig/*.cache-* ${config.xdg.cacheHome}/fontconfig/CACHEDIR.TAG
    fi

    run ${pkgs.fontconfig}/bin/fc-cache -r
  '';

  dconf.settings."org/gnome/desktop/interface" = {
    cursor-size = config.home.pointerCursor.size;
    cursor-theme = config.home.pointerCursor.name;
    font-name = "${config.gtk.font.name} ${toString config.gtk.font.size}";
    gtk-theme = config.gtk.theme.name;
    icon-theme = config.gtk.iconTheme.name;
  };

  # gtk's theme settings, generate files:
  #   1. ~/.gtkrc-2.0
  #   2. ~/.config/gtk-3.0/settings.ini
  #   3. ~/.config/gtk-4.0/settings.ini
  gtk = {
    enable = true;

    font = {
      # Use the system font set instead of adding a duplicate per-user font
      # package; stale user-profile fontconfig caches can break GTK/Cairo.
      name = "Noto Sans";
      size = 11;
    };

    gtk2.configLocation = "${config.xdg.configHome}/gtk-2.0/gtkrc";
    gtk4.theme = config.gtk.theme;

    iconTheme = {
      name = "fluent-light";
      package = pkgs.fluent-icon-theme.override {
        colorVariants = [ "pink" ];
      };
    };

    theme = {
      # https://github.com/vinceliuice/Fluent-gtk-theme
      name = "Fluent-round-pink-Light-compact";
      package = pkgs.fluent-gtk-theme.override {
        # https://github.com/NixOS/nixpkgs/blob/nixos-25.05/pkgs/by-name/fl/fluent-gtk-theme/package.nix
        themeVariants = [ "pink" ];
        colorVariants = [ "light" ];
        sizeVariants = [ "compact" ];
        tweaks = [ "round" ];
      };
    };
  };
}
