{
  lib,
  pkgs,
  agenix,
  mysecrets,
  myvars,
  ...
}:
{
  imports = [
    agenix.darwinModules.default
  ];

  launchd.daemons."activate-agenix".serviceConfig = {
    StandardErrorPath = "/Library/Logs/org.nixos.activate-agenix.stderr.log";
    StandardOutPath = "/Library/Logs/org.nixos.activate-agenix.stdout.log";
  };

  environment.systemPackages = [
    agenix.packages."${pkgs.stdenv.hostPlatform.system}".default
  ];

  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # agenix's darwin module honours `path` and applies owner and mode itself, so the
  # secrets go straight to /etc/agenix without environment.etc links.
  age.secrets =
    let
      hasSecretFile = path: builtins.pathExists path;
      optionalSecret =
        name: file: extra:
        lib.optionalAttrs (hasSecretFile file) ({
          "${name}" = {
            inherit file;
          }
          // extra;
        });
      high_security = {
        mode = "0500";
        owner = "root";
      };
      user_readable = {
        mode = "0500";
        owner = myvars.username;
      };
    in
    lib.mkMerge [
      (optionalSecret "rclone.conf" "${mysecrets}/rclone.conf.age" (
        high_security // { path = "/etc/agenix/rclone.conf"; }
      ))
      (optionalSecret "nix-access-tokens" "${mysecrets}/nix-access-tokens.age" user_readable)
      (optionalSecret "ssh-key-romantic" "${mysecrets}/ssh-key-romantic.age" (
        user_readable // { path = "/etc/agenix/ssh-key-romantic"; }
      ))
      # work git identity, symlinked to ~/work/.gitconfig by home-manager
      (optionalSecret "work-gitconfig" "${mysecrets}/desktop/work-gitconfig.age" (
        user_readable // { path = "/etc/agenix/work-gitconfig"; }
      ))
    ];

}
