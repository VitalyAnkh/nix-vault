{
  pkgs,
  config,
  lib,
  wallpapers,
  ...
}:
let
  hasCaddyTlsKey =
    config ? age && config.age ? secrets && config.age.secrets ? "caddy-ecc-server.key";

  hostCommonConfig = ''
    encode zstd gzip
  ''
  + lib.optionalString hasCaddyTlsKey ''
    tls ${../../certs/ecc-server.crt} ${config.age.secrets."caddy-ecc-server.key".path} {
      protocols tls1.3 tls1.3
      curves x25519 secp384r1 secp521r1
    }
  '';
in
{
  warnings = lib.optional (
    !hasCaddyTlsKey
  ) "aquamarine: age secret \"caddy-ecc-server.key\" missing; disabling services.caddy.";

  services.caddy = {
    enable = hasCaddyTlsKey;
    # Reload Caddy instead of restarting it when configuration file changes.
    enableReload = true;
    user = "caddy"; # User account under which caddy runs.
    dataDir = "/data/apps/caddy";
    logDir = "/var/log/caddy";

    # Additional lines of configuration appended to the global config section of the Caddyfile.
    # Refer to https://caddyserver.com/docs/caddyfile/options#global-options for details on supported values.
    globalConfig = ''
      http_port    80
      https_port   443
      auto_https   disable_certs
    '';

    # Dashboard
    virtualHosts."home.writefor.fun".extraConfig = ''
      ${hostCommonConfig}
      reverse_proxy http://localhost:54401
    '';

    # https://caddyserver.com/docs/caddyfile/directives/file_server
    virtualHosts."file.writefor.fun".extraConfig = ''
      root * /data/apps/caddy/fileserver/
      ${hostCommonConfig}
      file_server browse {
        hide .git
        precompressed zstd br gzip
      }
    '';

    virtualHosts."git.writefor.fun".extraConfig = ''
      ${hostCommonConfig}
      encode zstd gzip
      reverse_proxy http://localhost:3301
    '';
    virtualHosts."sftpgo.writefor.fun".extraConfig = ''
      ${hostCommonConfig}
      encode zstd gzip
      reverse_proxy http://localhost:3302
    '';
    virtualHosts."webdav.writefor.fun".extraConfig = ''
      ${hostCommonConfig}
      encode zstd gzip
      reverse_proxy http://localhost:3303
    '';
    virtualHosts."transmission.writefor.fun".extraConfig = ''
      ${hostCommonConfig}
      encode zstd gzip
      reverse_proxy http://localhost:9091
    '';

    # Monitoring
    virtualHosts."uptime-kuma.writefor.fun".extraConfig = ''
      ${hostCommonConfig}
      encode zstd gzip
      reverse_proxy http://localhost:53350
    '';
    virtualHosts."grafana.writefor.fun".extraConfig = ''
      ${hostCommonConfig}
      encode zstd gzip
      reverse_proxy http://localhost:3351
    '';
    virtualHosts."prometheus.writefor.fun".extraConfig = ''
      ${hostCommonConfig}
      encode zstd gzip
      reverse_proxy http://localhost:9090
    '';
    virtualHosts."alertmanager.writefor.fun".extraConfig = ''
      ${hostCommonConfig}
      encode zstd gzip
      reverse_proxy http://localhost:9093
    '';
    virtualHosts."vmalert.writefor.fun".extraConfig = ''
      ${hostCommonConfig}
      encode zstd gzip
      reverse_proxy http://localhost:8880
    '';
    virtualHosts."minio.writefor.fun".extraConfig = ''
      ${hostCommonConfig}
      encode zstd gzip
      reverse_proxy http://localhost:9096 {
        header_up Host {http.request.host}
        header_up X-Real-IP {http.request.remote.host}
        header_up X-Forwarded-For {http.request.header.X-Forwarded-For}
        header_up X-Forwarded-Proto {scheme}
        transport http {
            dial_timeout 300s
            read_timeout 300s
            write_timeout 300s
        }
      }
    '';
    virtualHosts."minio-ui.writefor.fun".extraConfig = ''
      ${hostCommonConfig}
      encode zstd gzip
      reverse_proxy http://localhost:9097 {
        header_up Host {http.request.host}
        header_up X-Real-IP {http.request.remote.host}
        header_up X-Forwarded-For {http.request.header.X-Forwarded-For}
        header_up X-Forwarded-Proto {scheme}
        header_up Upgrade {http.request.header.Upgrade}
        header_up Connection {http.request.header.Connection}
        transport http {
            dial_timeout 300s
            read_timeout 300s
            write_timeout 300s
        }
      }
    '';
    # Allow http access for specific api (do not redirect to https)
    # virtualHosts."http://xxx.writefor.fun/a/b/c".extraConfig = ''
    #   encode zstd gzip
    #   reverse_proxy http://localhost:9090
    # '';
  };
  networking.firewall.allowedTCPPorts = lib.optionals hasCaddyTlsKey [
    80
    443
  ];

  # Create Directories
  # https://www.freedesktop.org/software/systemd/man/latest/tmpfiles.d.html#Type
  systemd.tmpfiles.rules = lib.optionals hasCaddyTlsKey [
    "d /data/apps/caddy/fileserver/ 0755 caddy caddy"
    # directory for virtual machine's images
    "d /data/apps/caddy/fileserver/vms 0755 caddy caddy"
  ];

  # Add all my wallpapers into /data/apps/caddy/fileserver/wallpapers
  # Install the homepage-dashboard configuration files
  system.activationScripts = lib.optionalAttrs hasCaddyTlsKey {
    installCaddyWallpapers = ''
      mkdir -p /data/apps/caddy/fileserver/wallpapers
      ${pkgs.rsync}/bin/rsync -avz --chmod=D2755,F644 ${wallpapers}/ /data/apps/caddy/fileserver/wallpapers/
    '';
  };
}
