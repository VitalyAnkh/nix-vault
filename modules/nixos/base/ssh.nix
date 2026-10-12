{
  config,
  lib,
  pkgs,
  ...
}@args:
let
  cfg = config.vr.nixos.ssh;
  # GCC 16, the default compiler in nixpkgs unstable, fails to build contour and
  # the cache has no build, so take it from nixpkgs 26.05 (GCC 15). The
  # installer flake has no nixpkgs-stable input but turns installExtraTerminfo
  # off (nixos-installer/configuration.nix), so nothing uses this fallback;
  # turning it back on there would build unstable's contour.
  contour =
    if args ? nixpkgs-stable then
      args.nixpkgs-stable.legacyPackages.${pkgs.stdenv.buildPlatform.system}.contour
    else
      pkgs.pkgsBuildBuild.contour;
  terminfoPackages =
    with pkgs.pkgsBuildBuild;
    map (pkg: pkg.terminfo) [
      alacritty
      contour # from the binding above, which takes precedence over `with`
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
    # Secure by default: firewall ON everywhere. Servers run the same shared
    # firewall (modules/nixos/base/networking/firewall.nix) as every other host,
    # as defence in depth behind the router.
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

    # NixOS appends an `Include` of systemd's ssh_config.d drop-in to
    # /etc/ssh/ssh_config, and OpenSSH re-applies SSHCONF_CHECKPERM to included
    # files.  A bubblewrap sandbox (`--unshare-user`) exposes root-owned store
    # files as `nobody`, which would abort ssh there.  We do not use
    # systemd-ssh-proxy (.host, machine/*, unix/*, vsock/*).
    programs.ssh.systemd-ssh-proxy.enable = false;

    # Add common terminal terminfo entries to the system profile.
    # Do not use enableAllTerminfo directly: nixpkgs 26.05 includes obsolete
    # termite there, whose patched VTE currently fails to build.
    # https://github.com/NixOS/nixpkgs/blob/nixos-25.11/nixos/modules/config/terminfo.nix
    environment.enableAllTerminfo = lib.mkForce false;
    environment.systemPackages = lib.mkIf cfg.installExtraTerminfo terminfoPackages;
  };
}
