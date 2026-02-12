{
  pkgs,
  kubeconfigFile,
  tokenFile ? null,
  tokenSecretName ? null,
  # Initialize HA cluster using an embedded etcd datastore.
  # If you are configuring an HA cluster with an embedded etcd,
  # the 1st server must have `clusterInit = true`
  # and other servers must connect to it using `serverAddr`.
  #
  # this can be a domain name or an IP address(such as kube-vip's virtual IP)
  masterHost,
  clusterInit ? false,
  kubeletExtraArgs ? [ ],
  k3sExtraArgs ? [ ],
  nodeLabels ? [ ],
  nodeTaints ? [ ],
  disableFlannel ? true,
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

  environment.systemPackages =
    with pkgs;
    lib.optionals hasToken [
      package
      k9s
      kubectl
      istioctl
      kubernetes-helm
      cilium-cli
      fluxcd
      clusterctl # for kubernetes cluster-api

      skopeo # copy/sync images between registries and local storage
      go-containerregistry # provides `crane` & `gcrane`, it's similar to skopeo
      dive # explore docker layers
    ];

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
    inherit package clusterInit;
    tokenFile = tokenFilePath;
    serverAddr = if clusterInit then "" else "https://${masterHost}:6443";

    role = "server";
    # https://docs.k3s.io/cli/server
    extraFlags =
      let
        flagList = [
          "--write-kubeconfig=${kubeconfigFile}"
          "--write-kubeconfig-mode=644"
          "--service-node-port-range=80-32767"
          "--kube-apiserver-arg='--allow-privileged=true'" # required by kubevirt
          "--data-dir /var/lib/rancher/k3s"
          "--etcd-expose-metrics=true"
          "--etcd-snapshot-schedule-cron='0 */12 * * *'"
          # disable some features we don't need
          "--disable-helm-controller" # we use fluxcd instead
          "--disable=traefik" # deploy our own ingress controller instead
          "--disable=servicelb" # we use kube-vip instead
          "--disable-network-policy"
          "--tls-san=${masterHost}"
        ]
        ++ (map (label: "--node-label=${label}") nodeLabels)
        ++ (map (taint: "--node-taint=${taint}") nodeTaints)
        ++ (map (arg: "--kubelet-arg=${arg}") kubeletExtraArgs)
        ++ (lib.optionals disableFlannel [ "--flannel-backend=none" ])
        ++ k3sExtraArgs;
      in
      lib.concatStringsSep " " flagList;
  };

  # Create symlinks to link k3s's cni directory to the one used by almost all CNI plugins,
  # such as multus, calico, etc.
  # https://www.freedesktop.org/software/systemd/man/latest/tmpfiles.d.html#Type
  systemd.tmpfiles.rules = lib.optionals hasToken [
    # https://docs.k3s.io/networking/multus-ipams
    "L+ /opt/cni/bin - - - - /var/lib/rancher/k3s/data/cni/"
    # If you have disabled flannel, you will have to create the directory via a tmpfiles rule
    "d /var/lib/rancher/k3s/agent/etc/cni/net.d 0751 root root - -"
    # Link the CNI config directory
    "L+ /etc/cni/net.d - - - - /var/lib/rancher/k3s/agent/etc/cni/net.d"
  ];
}
