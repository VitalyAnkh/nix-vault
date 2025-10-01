{ pkgs-unstable, ... }:
{
  home.packages =
    with pkgs-unstable;
    [
      mitmproxy # http/https proxy tool
      wireshark # network analyzer

      xorg.xeyes

      # IDEs
      jetbrains-toolbox

      # AI cli tools
      k8sgpt
      kubectl-ai # an ai helper opensourced by google
    ]
    ++ (lib.optionals pkgs.stdenv.isx86_64 [
      insomnia # REST client
    ]);
}
