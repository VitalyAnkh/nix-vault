{ config, lib, ... }:
let
  # Upstream (6218bb22) prepends Homebrew here. Appending keeps Nix packages ahead
  # of Homebrew's, which astra's PATH order relies on (docs/astra-macos-host.md).
  envExtra = ''
    export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"
  '';
in
{
  # Homebrew's default install location:
  #   /opt/homebrew for Apple Silicon
  #   /usr/local for macOS Intel
  # The prefix /opt/homebrew was chosen to allow installations
  # in /opt/homebrew for Apple Silicon and /usr/local for Rosetta 2 to coexist and use bottles.
  programs.bash = {
    enable = true;
    bashrcExtra = lib.mkAfter envExtra;
  };
  programs.zsh = {
    enable = true;
    inherit envExtra;
    # Adopt the new behavior (XDG config directory).
    dotDir = "${config.xdg.configHome}/zsh";
  };
}
