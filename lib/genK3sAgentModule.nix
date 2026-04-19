{
  pkgs,
  masterHost,
  tokenFile ? null,
  tokenSecretName ? null,
  nodeLabels ? [ ],
  k3sExtraArgs ? [ ],
  ...
}:
let
  package = pkgs.k3s;
in
{ config, lib, ... }:
let
  tokenFromAgeSecret =
    tokenFile == null
    && tokenSecretName != null
    && config ? age
    && config.age ? secrets
    && config.age.secrets ? tokenSecretName;
  hasToken = tokenFile != null || tokenFromAgeSecret;

  tokenFilePath = if tokenFile != null then tokenFile else config.age.secrets.${tokenSecretName}.path;
in
{
  warnings = lib.optional (
    tokenFile == null && tokenSecretName != null && !tokenFromAgeSecret
  ) "k3s: age secret \"${tokenSecretName}\" missing; disabling services.k3s.";

  environment.systemPackages = lib.optionals hasToken [ package ];

  # Kernel modules required by cilium
  boot.kernelModules = lib.optionals hasToken [
    "ip6_tables"
    "ip6table_mangle"
    "ip6table_raw"
    "ip6table_filter"
  ];

  networking = lib.mkIf hasToken {
    enableIPv6 = true;
    nat = {
      enable = true;
      enableIPv6 = true;
    };
  };

  services.k3s = lib.mkIf hasToken {
    enable = true;
    inherit package;
    tokenFile = tokenFilePath;

    role = "agent";
    serverAddr = "https://${masterHost}:6443";
    # https://docs.k3s.io/cli/agent
    extraFlags =
      let
        flagList = [
          "--data-dir /var/lib/rancher/k3s"
        ]
        ++ (map (label: "--node-label=${label}") nodeLabels)
        ++ k3sExtraArgs;
      in
      pkgs.lib.concatStringsSep " " flagList;
  };
}
