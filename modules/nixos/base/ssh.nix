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
    # Or disable the firewall altogether.
    networking.firewall.enable = lib.mkDefault false;
    # Enable the OpenSSH daemon.
    services.openssh = {
      enable = true;
      settings = {
        X11Forwarding = true;
        # root user is used for remote deployment, so we need to allow it
        PermitRootLogin = "prohibit-password";
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
