{
  lib,
  config,
  pkgs,
  agenix,
  mysecrets,
  myvars,
  ...
}:
with lib;
let
  cfg = config.modules.secrets;

  enabledServerSecrets = any (v: v) [
    cfg.server.application.enable
    cfg.server.network.enable
    cfg.server.operation.enable
    cfg.server.kubernetes.enable
    cfg.server.webserver.enable
    cfg.server.storage.enable
  ];

  hasSecretFile = path: builtins.pathExists path;

  firstExisting =
    paths:
    let
      existing = builtins.filter hasSecretFile paths;
    in
    if existing == [ ] then null else builtins.head existing;

  optionalSecret =
    name: file: extra:
    optionalAttrs (hasSecretFile file) {
      "${name}" = {
        inherit file;
      }
      // extra;
    };

  optionalEtc =
    target: secretName: file: extra:
    optionalAttrs (hasSecretFile file) {
      "${target}" = {
        source = config.age.secrets.${secretName}.path;
      }
      // extra;
    };

  optionalSecretFrom =
    name: files: extra:
    let
      file = firstExisting files;
    in
    optionalAttrs (file != null) {
      "${name}" = {
        inherit file;
      }
      // extra;
    };

  optionalEtcFrom =
    target: secretName: files: extra:
    optionalAttrs (firstExisting files != null) {
      "${target}" = {
        source = config.age.secrets.${secretName}.path;
      }
      // extra;
    };

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
{
  imports = [
    agenix.nixosModules.default
  ];

  options.modules.secrets = {
    desktop.enable = mkEnableOption "NixOS Secrets for Desktops";

    server.network.enable = mkEnableOption "NixOS Secrets for Network Servers";
    server.application.enable = mkEnableOption "NixOS Secrets for Application Servers";
    server.operation.enable = mkEnableOption "NixOS Secrets for Operation Servers(Backup, Monitoring, etc)";
    server.kubernetes.enable = mkEnableOption "NixOS Secrets for Kubernetes";
    server.webserver.enable = mkEnableOption "NixOS Secrets for Web Servers(contains tls cert keys)";
    server.storage.enable = mkEnableOption "NixOS Secrets for HDD Data's LUKS Encryption";

    preservation.enable = mkEnableOption "whether use preservation and ephemeral root file system";
  };

  config = mkIf (cfg.desktop.enable || enabledServerSecrets) (mkMerge [
    {
      environment.systemPackages = [
        agenix.packages."${pkgs.stdenv.hostPlatform.system}".default
      ];

      # if you changed this key, you need to regenerate all encrypt files from the decrypt contents!
      age.identityPaths =
        if cfg.preservation.enable then
          [
            # To decrypt secrets on boot, this key should exists when the system is booting,
            # so we should use the real key file path(prefixed by `/persistent/`) here, instead of the path mounted by preservation.
            "/persistent/etc/ssh/ssh_host_ed25519_key" # Linux
          ]
        else
          [
            "/etc/ssh/ssh_host_ed25519_key"
          ];

      # secrets that are used by all nixos hosts
      age.secrets = mkMerge [
        (optionalSecretFrom "nix-access-tokens" [
          "${mysecrets}/nix-access-tokens.age"
          "${mysecrets}/server/nix-access-tokens.age"
        ] user_readable)
      ];

      assertions = [
        {
          # This expression should be true to pass the assertion
          assertion = !(cfg.desktop.enable && enabledServerSecrets);
          message = "Enable either desktop or server's secrets, not both!";
        }
      ];
    }

    (mkIf cfg.desktop.enable {
      age.secrets = mkMerge [
        # ---------------------------------------------
        # No discretionary access; privileged root can still bypass file modes.
        # ---------------------------------------------

        # .age means the decrypted file is still encrypted by age(via a passphrase)
        (optionalSecretFrom "vitalyr-gpg-subkeys.priv.age" [
          "${mysecrets}/vitalyr-gpg-subkeys-2024-01-27.priv.age.age"
        ] noaccess)
        # ---------------------------------------------
        # only root can read this file.
        # ---------------------------------------------

        (optionalSecret "wg-business.conf" "${mysecrets}/wg-business.conf.age" high_security)

        # Used only by NixOS Modules
        # smb-credentials is referenced in /etc/fstab, by ../hosts/ai/cifs-mount.nix
        (optionalSecret "smb-credentials" "${mysecrets}/smb-credentials.age" high_security)

        (optionalSecretFrom "rclone.conf" [
          "${mysecrets}/rclone.conf.age"
          "${mysecrets}/desktop/rclone.conf.age"
        ] high_security)

        # ---------------------------------------------
        # user can read this file.
        # ---------------------------------------------

        (optionalSecretFrom "ssh-key-romantic" [
          "${mysecrets}/ssh-key-romantic.age"
          "${mysecrets}/desktop/ssh-key-romantic.age"
        ] user_readable)

        # alias-for-work
        (optionalSecret "alias-for-work.nushell" "${mysecrets}/alias-for-work.nushell.age" user_readable)
        # Work git identity, symlinked to ~/work/.gitconfig by Home Manager.
        (optionalSecretFrom "work-gitconfig" [ "${mysecrets}/desktop/work-gitconfig.age" ] user_readable)
      ];

      # place secrets in /etc/
      environment.etc = mkMerge [
        # wireguard config used with `wg-quick up wg-business`
        (optionalEtc "wireguard/wg-business.conf" "wg-business.conf" "${mysecrets}/wg-business.conf.age"
          { }
        )

        (optionalEtcFrom "agenix/rclone.conf" "rclone.conf" [
          "${mysecrets}/rclone.conf.age"
          "${mysecrets}/desktop/rclone.conf.age"
        ] { })

        (optionalEtcFrom "agenix/ssh-key-romantic" "ssh-key-romantic"
          [
            "${mysecrets}/ssh-key-romantic.age"
            "${mysecrets}/desktop/ssh-key-romantic.age"
          ]
          {
            mode = "0600";
            user = myvars.username;
          }
        )

        (optionalEtcFrom "agenix/vitalyr-gpg-subkeys.priv.age" "vitalyr-gpg-subkeys.priv.age" [
          "${mysecrets}/vitalyr-gpg-subkeys-2024-01-27.priv.age.age"
        ] { mode = "0000"; })

        # The following secrets are used by home-manager modules
        # So we need to make then readable by the user
        (optionalEtc "agenix/alias-for-work.nushell" "alias-for-work.nushell"
          "${mysecrets}/alias-for-work.nushell.age"
          {
            mode = "0400";
            user = myvars.username;
          }
        )
        (optionalEtcFrom "agenix/work-gitconfig" "work-gitconfig"
          [
            "${mysecrets}/desktop/work-gitconfig.age"
          ]
          {
            mode = "0400";
            user = myvars.username;
          }
        )
      ];
    })

    (mkIf cfg.server.network.enable {
      age.secrets = mkMerge [
        (optionalSecret "dae-subscription.dae" "${mysecrets}/server/dae-subscription.dae.age" high_security)
      ];
    })

    (mkIf cfg.server.application.enable {
      age.secrets = mkMerge [
        (optionalSecret "transmission-credentials.json"
          "${mysecrets}/server/transmission-credentials.json.age"
          high_security
        )

        (optionalSecret "sftpgo.env" "${mysecrets}/server/sftpgo.env.age" {
          mode = "0400";
          owner = "sftpgo";
        })

        # RustFS root credentials used by the homelab object-store service.
        (optionalSecret "rustfs.env" "${mysecrets}/server/rustfs.env.age" {
          mode = "0400";
          owner = "root";
        })
      ];
    })

    (mkIf cfg.server.operation.enable {
      age.secrets = mkMerge [
        (optionalSecret "grafana-admin-password" "${mysecrets}/server/grafana-admin-password.age" {
          mode = "0400";
          owner = "grafana";
        })

        (optionalSecret "grafana-secret-key" "${mysecrets}/server/grafana-secret-key.age" {
          mode = "0400";
          owner = "grafana";
        })

        (optionalSecret "postgres-playground-password"
          "${mysecrets}/server/postgres-playground-password.age"
          high_security
        )

        (optionalSecret "alertmanager.env" "${mysecrets}/server/alertmanager.env.age" high_security)
      ];
    })

    (mkIf cfg.server.kubernetes.enable {
      age.secrets = mkMerge [
        (optionalSecret "k3s-prod-1-token" "${mysecrets}/server/k3s-prod-1-token.age" high_security)

        (optionalSecret "k3s-test-1-token" "${mysecrets}/server/k3s-test-1-token.age" high_security)
      ];
    })

    (mkIf cfg.server.webserver.enable {
      age.secrets = mkMerge [
        (optionalSecret "caddy-ecc-server.key" "${mysecrets}/certs/ecc-server.key.age" {
          mode = "0400";
          owner = "caddy";
        })

        (optionalSecret "postgres-ecc-server.key" "${mysecrets}/certs/ecc-server.key.age" {
          mode = "0400";
          owner = "postgres";
        })

        (optionalSecret "cloudflare-dns-api-token" "${mysecrets}/server/cloudflare-dns-api-token.env.age" {
          mode = "0400";
          owner = "root";
        })
      ];
    })

    (mkIf cfg.desktop.enable {
      # Desktop backups use a separate repository password from homelab hosts.
      age.secrets = mkMerge [
        (optionalSecretFrom "restic-password"
          [
            "${mysecrets}/desktop/restic-password-desktop.age"
          ]
          {
            mode = "0400";
            owner = "root";
          }
        )
        (optionalSecretFrom "restic-rest-credentials"
          [
            "${mysecrets}/desktop/restic-rest-credentials.age"
          ]
          {
            mode = "0400";
            owner = "root";
          }
        )
      ];
    })

    (mkIf cfg.server.storage.enable {
      age.secrets = mkMerge [
        (optionalSecretFrom "hdd-luks-crypt-key"
          [
            "${mysecrets}/hdd-luks-crypt-key.age"
            "${mysecrets}/server/hdd-luks-crypt-key.age"
          ]
          {
            mode = "0400";
            owner = "root";
          }
        )

        (optionalSecretFrom "restic-password"
          [
            "${mysecrets}/restic-password-homelab.age"
            "${mysecrets}/server/restic-password-homelab.age"
          ]
          {
            mode = "0400";
            owner = "root";
          }
        )

        (optionalSecretFrom "restic-rest-htpasswd"
          [
            "${mysecrets}/restic-rest-htpasswd.age"
            "${mysecrets}/server/restic-rest-htpasswd.age"
          ]
          {
            mode = "0400";
            owner = "restic";
          }
        )
      ];

      # place secrets in /etc/
      environment.etc = mkMerge [
        (optionalEtcFrom "agenix/hdd-luks-crypt-key" "hdd-luks-crypt-key"
          [
            "${mysecrets}/hdd-luks-crypt-key.age"
            "${mysecrets}/server/hdd-luks-crypt-key.age"
          ]
          {
            mode = "0400";
            user = "root";
          }
        )
      ];
    })
  ]);
}
