{ pkgs, ... }:
{
  home.packages =
    with pkgs;
    [
      mitmproxy # http/https proxy tool
      wireshark # network analyzer

      bottom

      xorg.xeyes

      ninja
      uv
      trash-cli

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
