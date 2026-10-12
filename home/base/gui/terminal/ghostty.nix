{
  pkgs,
  ...
}:
###########################################################
#
# Ghostty Configuration
#
# TUIOS provides tabs, panes, scrollback and copy mode, so ghostty
# only needs a font, transparency and the kitty graphics protocol
# (built in).
#
###########################################################
{
  programs.ghostty = {
    enable = true;
    package =
      if pkgs.stdenv.hostPlatform.isDarwin then
        null # installed via Homebrew cask on darwin
      else
        pkgs.ghostty;
    enableBashIntegration = false;
    installBatSyntax = false;
    settings = {
      font-family = "Maple Mono NF CN";
      font-size = 13;

      # hide title bar/header bar (Linux only; on macOS it would remove the traffic lights too)
      window-decoration = pkgs.stdenv.hostPlatform.isDarwin;

      # transparency
      background-opacity = 0.85;
      background-blur-radius = 10; # macOS only

      # Start fullscreen on macOS; window managers control this on Linux.
      fullscreen = pkgs.stdenv.hostPlatform.isDarwin;

      # https://ghostty.org/docs/config/reference#command
      # Spawn a nushell in login mode via `bash`
      command = "${pkgs.bash}/bin/bash --login -c 'nu --login --interactive'";
    };
  };
}
