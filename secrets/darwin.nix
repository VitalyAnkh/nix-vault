{
  lib,
  config,
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
      noaccess = {
        mode = "0000";
        owner = "root";
      };
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
      (optionalSecret "vitalyr-gpg-subkeys.priv.age"
        "${mysecrets}/vitalyr-gpg-subkeys-2024-01-27.priv.age.age"
        noaccess
      )
      (optionalSecret "rclone.conf" "${mysecrets}/rclone.conf.age" high_security)
      (optionalSecret "nix-access-tokens" "${mysecrets}/nix-access-tokens.age" user_readable)
      (optionalSecret "ssh-key-romantic" "${mysecrets}/ssh-key-romantic.age" user_readable)
      (optionalSecret "work-gitconfig" "${mysecrets}/desktop/work-gitconfig.age" user_readable)
    ];

  environment.etc = lib.mkMerge [
    (lib.optionalAttrs (builtins.hasAttr "rclone.conf" config.age.secrets) {
      "agenix/rclone.conf".source = config.age.secrets."rclone.conf".path;
    })
    (lib.optionalAttrs (builtins.hasAttr "ssh-key-romantic" config.age.secrets) {
      "agenix/ssh-key-romantic".source = config.age.secrets."ssh-key-romantic".path;
    })
    (lib.optionalAttrs (builtins.hasAttr "vitalyr-gpg-subkeys.priv.age" config.age.secrets) {
      "agenix/vitalyr-gpg-subkeys.priv.age".source =
        config.age.secrets."vitalyr-gpg-subkeys.priv.age".path;
    })
    (lib.optionalAttrs (builtins.hasAttr "work-gitconfig" config.age.secrets) {
      "agenix/work-gitconfig".source = config.age.secrets."work-gitconfig".path;
    })
  ];

  # nix-darwin ignores environment.etc mode/owner; restore the intended
  # ownership after activation without widening root-only secrets.
  system.activationScripts.postActivation.text = ''
    if [ -d /etc/agenix ]; then
      for file in ssh-key-romantic work-gitconfig; do
        if [ -e "/etc/agenix/$file" ]; then
          ${pkgs.coreutils}/bin/chown ${myvars.username} "/etc/agenix/$file"
          ${pkgs.coreutils}/bin/chmod 0500 "/etc/agenix/$file"
        fi
      done
      if [ -e /etc/agenix/rclone.conf ]; then
        ${pkgs.coreutils}/bin/chown root /etc/agenix/rclone.conf
        ${pkgs.coreutils}/bin/chmod 0500 /etc/agenix/rclone.conf
      fi
      if [ -e /etc/agenix/vitalyr-gpg-subkeys.priv.age ]; then
        ${pkgs.coreutils}/bin/chown root /etc/agenix/vitalyr-gpg-subkeys.priv.age
        ${pkgs.coreutils}/bin/chmod 0000 /etc/agenix/vitalyr-gpg-subkeys.priv.age
      fi
    fi
  '';
}
