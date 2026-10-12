{
  config,
  lib,
  osConfig ? { },
  ...
}:
{
  # Work git identity (email/name), decrypted from nix-secrets. ~/work/.gitconfig
  # is what `programs.git.includes` (home/base/core/git.nix) tells git to read
  # for repos under ~/work.
  #
  # This lives in the desktop layer rather than core: base/gui is imported only
  # by hosts that declare the desktop secret (the NixOS desktops via
  # home/linux/gui.nix and macOS via home/darwin), so the consumer and the
  # secret share the same gate. The private secrets repository here may not
  # carry that secret (secrets/nixos.nix and secrets/darwin.nix skip missing
  # files), so link it only when the host declares it.
  home.file."work/.gitconfig" = lib.mkIf ((osConfig.age.secrets or { }) ? "work-gitconfig") {
    source = config.lib.file.mkOutOfStoreSymlink "/etc/agenix/work-gitconfig";
  };
}
