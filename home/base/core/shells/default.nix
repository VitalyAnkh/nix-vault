{
  config,
  pkgs-unstable,
  ...
}:
let
  shellAliases = {
    k = "kubectl";
    ec = "emacsclient --create-frame";
    j = "just -f ~/nix-vault/justfile";
    ncpp = "nix develop ~/nix-vault/templates/cpp";
    nrust = "nix develop ~/nix-vault/templates/bevy";

    urldecode = "python3 -c 'import sys, urllib.parse as ul; print(ul.unquote_plus(sys.stdin.read()))'";
    urlencode = "python3 -c 'import sys, urllib.parse as ul; print(ul.quote_plus(sys.stdin.read()))'";
  };

  localBin = "${config.home.homeDirectory}/.local/bin";
  goBin = "${config.home.homeDirectory}/go/bin";
  rustBin = "${config.home.homeDirectory}/.cargo/bin";
  npmBin = "${config.home.homeDirectory}/.npm/bin";
  pnpmBin = "${config.home.homeDirectory}/.local/share/pnpm";
  miniforgeBin = "${config.home.homeDirectory}/miniforge3/bin";
in
{
  # only works in bash/zsh, not nushell
  home.shellAliases = shellAliases;

  programs.fish = {
    enable = true;
    package = pkgs-unstable.fish;
    #configFile.source = ./config.nu;
    inherit shellAliases;
  };

  programs.bash = {
    enable = true;
    enableCompletion = true;
    bashrcExtra = ''
      export PATH="$PATH:${localBin}:${pnpmBin}:${goBin}:${rustBin}:${npmBin}"
    '';
  };

  # NOTE: only works in bash/zsh, not nushell
  # home.shellAliases = shellAliases;

  # NOTE: nushell will be launched in bash, so it can inherit all the environment variables.
  programs.nushell = {
    enable = true;
    configFile.source = ./config.nu;
    inherit shellAliases;
  };
}
