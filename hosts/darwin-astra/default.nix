{ myvars, ... }:
let
  hostname = "astra";
in
{
  imports = [ ./homebrew.nix ];

  networking.hostName = hostname;
  networking.computerName = hostname;
  system.defaults.smb.NetBIOSName = hostname;
  system.primaryUser = myvars.username;
  system.stateVersion = 7;
  time.timeZone = "Asia/Singapore";

  # nix-darwin manages Nix here, unlike modules/darwin/nix-core.nix (Determinate Nix on
  # fern and frieren); automatic GC is off, as there. Store optimisation stays off too,
  # although upstream dropped its Darwin workaround for nix#7273 (d056aece).
  nix.enable = true;
  nix.settings.auto-optimise-store = false;
  nix.gc.automatic = false;
  # Home Manager runs compinit after adding its completion paths; a second,
  # global run from /etc/zshrc would only slow down every interactive shell.
  programs.zsh.enableGlobalCompInit = false;
  modules.desktop.fonts.enable = true;

  # macOS already includes /etc/pam.d/sudo_local from /etc/pam.d/sudo, and the
  # file nix-darwin would generate here is empty. Not managing it avoids writing
  # under /etc/pam.d, which macOS privacy protection (TCC) blocks unless the
  # activating terminal has Full Disk Access. Enable it to use touchIdAuth.
  security.pam.services.sudo_local.enable = false;
}
