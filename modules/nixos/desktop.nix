{
  pkgs,
  config,
  lib,
  myvars,
  ...
}:
with lib; let
  cfgWayland = config.modules.desktop.wayland;
  cfgXorg = config.modules.desktop.xorg;
in {
  imports = [
    ./base
    ../base.nix

    ./desktop
  ];

  options.modules.desktop = {
    wayland = {
      enable = mkEnableOption "Wayland Display Server";
    };
    xorg = {
      enable = mkEnableOption "Xorg Display Server";
    };
  };

  config = mkMerge [
    (mkIf cfgWayland.enable {
      ####################################################################
      #  NixOS's Configuration for Wayland based Window Manager
      ####################################################################
      xdg.portal = {
        enable = true;
        wlr.enable = true;
        extraPortals = with pkgs; [
          xdg-desktop-portal-wlr
          xdg-desktop-portal-gnome
        ];
      };

      services = {
        xserver.enable = true;
        xserver.displayManager.gdm.enable = true;
        xserver.desktopManager.gnome.enable = true;

        # https://wiki.archlinux.org/title/Greetd
        #greetd = {
        #  enable = true;
        #  settings = {
        #    default_session = {
        #      # Wayland Desktop Manager is installed only for user ryan via home-manager!
        #      user = myvars.username;
        #      # .wayland-session is a script generated by home-manager, which links to the current wayland compositor(sway/hyprland or others).
        #      # with such a vendor-no-locking script, we can switch to another wayland compositor without modifying greetd's config here.
        #      command = "$HOME/.wayland-session"; # start a wayland session directly without a login manager
        #      # command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd $HOME/.wayland-session";  # start wayland session with a TUI login manager
        #    };
        #  };
        #};
      };

      # fix https://github.com/ryan4yin/nix-config/issues/10
      #security.pam.services.swaylock = {};
    })

    (mkIf cfgXorg.enable {
      ####################################################################
      #  NixOS's Configuration for Xorg Server
      ####################################################################

      services = {
        gvfs.enable = true; # Mount, trash, and other functionalities
        tumbler.enable = true; # Thumbnail support for images

        xserver = {
          enable = true;
          displayManager = {
            lightdm.enable = true;
            autoLogin = {
              enable = true;
              user = myvars.username;
            };
            # use a fake session to skip desktop manager
            # and let Home Manager take care of the X session
            defaultSession = "hm-session";
          };
          desktopManager = {
            runXdgAutostartIfNone = true;
            session = [
              {
                name = "hm-session";
                manage = "window";
                start = ''
                  ${pkgs.runtimeShell} $HOME/.xsession &
                  waitPID=$!
                '';
              }
            ];
          };
          # Configure keymap in X11
          xkb.layout = "us";
        };
      };
    })
  ];
}
