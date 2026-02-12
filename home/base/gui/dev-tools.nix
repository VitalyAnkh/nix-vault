{
  lib,
  pkgs,
  ...
}:
{
  home.packages =
    with pkgs;
    [
      # IDEs
      jetbrains-toolbox

      # AI cli tools
      k8sgpt
      kubectl-ai # an ai helper opensourced by google
    ]
    ++ (lib.optionals stdenv.isLinux [
      mitmproxy # http/https proxy tool
      wireshark # network analyzer

      xorg.xeyes
      xvfb-run
    ])
    ++ (lib.optionals stdenv.isx86_64 [
      insomnia # REST client
    ]);
}
