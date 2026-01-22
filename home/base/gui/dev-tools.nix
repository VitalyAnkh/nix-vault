{
  lib,
  pkgs,
  ...
}:
{
  home.packages =
    with pkgs;
    [
      mitmproxy # http/https proxy tool
      wireshark # network analyzer

      # IDEs
      jetbrains-toolbox

      # AI cli tools
      k8sgpt
      kubectl-ai # an ai helper opensourced by google
    ]
    ++ (lib.optionals stdenv.isLinux [
      xorg.xeyes
      xvfb-run
    ])
    ++ (lib.optionals stdenv.isx86_64 [
      insomnia # REST client
    ]);
}
