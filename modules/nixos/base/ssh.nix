{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vr.nixos.ssh;
  terminfoPackages =
    with pkgs.pkgsBuildBuild;
    map (pkg: pkg.terminfo) [
      alacritty
      contour
      foot
      ghostty
      kitty
      mtm
      rio
      rxvt-unicode-unwrapped
      rxvt-unicode-unwrapped-emoji
      st
      tmux
      wezterm
      yaft
    ];
in
{
  options.vr.nixos.ssh.installExtraTerminfo = lib.mkOption {
    default = true;
    type = lib.types.bool;
    description = ''
      Whether to install extra terminal terminfo entries for SSH sessions.
    '';
  };

  config = {
    # Secure by default: firewall ON everywhere unless a host explicitly disables it
    # (servers disable it in modules/nixos/server/{server,server-aarch64}.nix).
    networking.firewall.enable = lib.mkDefault true;
    # Enable the OpenSSH daemon.
    services.openssh = {
      enable = true;
      settings = {
        # Secure by default: X11 forwarding off everywhere; desktops re-enable it
        # in modules/nixos/desktop/ssh.nix (needed for GUI forwarding).
        X11Forwarding = lib.mkDefault false;
        # root login stays available for Colmena/MicroVM deployment, keys only
        PermitRootLogin = lib.mkDefault "prohibit-password";
        PasswordAuthentication = false; # disable password login
      };
      openFirewall = true;
    };

    # Add common terminal terminfo entries to the system profile.
    # Do not use enableAllTerminfo directly: nixpkgs 26.05 includes obsolete
    # termite there, whose patched VTE currently fails to build.
    # https://github.com/NixOS/nixpkgs/blob/nixos-25.11/nixos/modules/config/terminfo.nix
    environment.enableAllTerminfo = lib.mkForce false;
    environment.systemPackages = lib.mkIf cfg.installExtraTerminfo terminfoPackages;
  };
}
