{ config, ... }:
let
  hostName = "muon";
in
{
  imports = [ ../../linux/gui.nix ];

  # GNOME remains the default session; retain Niri configuration for opt-in use.
  modules.desktop.niri.enable = false;
  modules.desktop.nvidia.enable = true;
  modules.editors.emacs.enable = true;

  programs.fish.enable = true;

  programs.ssh.settings."github.com".IdentityFile = "${config.home.homeDirectory}/.ssh/${hostName}";

  programs.zed-editor.userSettings = {
    ui_font_size = 18.0;
    buffer_font_size = 17.0;
    agent_ui_font_size = 18.0;
    agent_buffer_font_size = 17.0;
  };
}
