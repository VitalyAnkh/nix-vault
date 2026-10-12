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
  # Voice input (fcitx5-vinput), as on eva; one-time model setup in
  # home/linux/gui/base/vinput/README.md.
  modules.desktop.vinput.enable = true;

  programs.fish.enable = true;

  programs.ssh.settings."github.com".IdentityFile = "${config.home.homeDirectory}/.ssh/${hostName}";

  programs.zed-editor.userSettings = {
    ui_font_size = 18.0;
    buffer_font_size = 17.0;
    agent_ui_font_size = 18.0;
    agent_buffer_font_size = 17.0;
  };

  # Desktop speakers: EBU R128 broadcast-standard target, same as eva / upstream ai host.
  services.easyeffects.extraPresets."loudness-normalization".output."autogain#0".target = -23.0;
}
