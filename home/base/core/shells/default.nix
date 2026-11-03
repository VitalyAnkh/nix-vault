{
  config,
  lib,
  myvars,
  pkgs,
  ...
}:
let
  repoRoot = myvars.repoRoot or "${config.home.homeDirectory}/nix-vault";
  repoAliases = quote: {
    j = "just -f ${quote "${repoRoot}/justfile"}";
    ncpp = "nix develop ${quote "${repoRoot}/templates/cpp"}";
    nrust = "nix develop ${quote "${repoRoot}/templates/bevy"}";
    nweb = "nix develop ${quote "${repoRoot}/templates/web"}";
  };

  shellAliases = {
    k = "kubectl";
    ec = "emacsclient --create-frame";

    urldecode = "python3 -c 'import sys, urllib.parse as ul; print(ul.unquote_plus(sys.stdin.read()))'";
    urlencode = "python3 -c 'import sys, urllib.parse as ul; print(ul.quote_plus(sys.stdin.read()))'";
  }
  // repoAliases lib.escapeShellArg;

  localBin = "${config.home.homeDirectory}/.local/bin";
  goBin = "${config.home.homeDirectory}/go/bin";
  rustBin = "${config.home.homeDirectory}/.cargo/bin";
  npmBin = "${config.modules.npm.prefix}/bin";
  pnpmHome = "${config.home.homeDirectory}/.local/share/pnpm";
  pnpmBin = "${pnpmHome}/bin";
in
{
  # Home Manager passes these to bash, zsh, fish and nushell.
  home.shellAliases = shellAliases;
  # Tools installed outside Nix. Every shell, including nushell (through
  # loadSessionVariables), prepends these to PATH.
  home.sessionPath = [
    pnpmBin
    pnpmHome
    localBin
    goBin
    rustBin
    npmBin
  ];

  programs.fish = {
    enable = true;
    package = pkgs.fish;
    #configFile.source = ./config.nu;
    inherit shellAliases;
  };

  programs.bash = {
    enable = true;
    enableCompletion = true;
  };

  # The terminals start nushell directly; it reads Home Manager's session
  # environment from env.nu (loadSessionVariables).
  programs.nushell = {
    enable = true;
    loadSessionVariables = true;
    configFile.source = ./config.nu;
    # Nushell uses its own string grammar rather than POSIX shell escaping.
    # Override only the repository aliases inherited from home.shellAliases.
    shellAliases = lib.mapAttrs (_: lib.mkForce) (repoAliases builtins.toJSON);
  };

}
