{
  lib,
  pkgs,
  ...
}:
let
  gkeGcloudAuthPlugin =
    if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then
      pkgs.google-cloud-sdk.components.gke-gcloud-auth-plugin-linux-x86_64
    else if pkgs.stdenv.hostPlatform.system == "i686-linux" then
      pkgs.google-cloud-sdk.components.gke-gcloud-auth-plugin-linux-x86
    else if pkgs.stdenv.hostPlatform.system == "aarch64-linux" then
      pkgs.google-cloud-sdk.components.gke-gcloud-auth-plugin-linux-arm
    else if pkgs.stdenv.hostPlatform.system == "x86_64-darwin" then
      pkgs.google-cloud-sdk.components.gke-gcloud-auth-plugin-darwin-x86_64
    else if pkgs.stdenv.hostPlatform.system == "aarch64-darwin" then
      pkgs.google-cloud-sdk.components.gke-gcloud-auth-plugin-darwin-arm
    else
      null;
in
{
  # https://developer.hashicorp.com/terraform/cli/config/config-file
  home.file.".terraformrc".source = ./terraformrc;

  home.packages =
    with pkgs;
    [
      # infrastructure as code
      # pulumi
      # pulumictl
      # tf2pulumi
      # crd2pulumi
      # pulumiPackages.pulumi-random
      # pulumiPackages.pulumi-command
      # pulumiPackages.pulumi-aws-native
      # pulumiPackages.pulumi-language-go
      # pulumiPackages.pulumi-language-python
      # pulumiPackages.pulumi-language-nodejs

      # aws
      awscli2
      ssm-session-manager-plugin # Amazon SSM Session Manager Plugin
      aws-iam-authenticator
      eksctl

      # aliyun
      aliyun-cli
      # digitalocean
      doctl
      # google cloud
      google-cloud-sdk

      # cloud tools that nix do not have cache for.
      #terraform
      #terraformer # generate terraform configs from existing cloud resources
      #packer # machine image builder
    ]
    ++ lib.optional (gkeGcloudAuthPlugin != null) gkeGcloudAuthPlugin;
}
