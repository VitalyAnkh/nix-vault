{
  lib,
  pkgs,
  ...
}:
{
  # Agent CLIs from llm-agents live in home/base/tui/agents/packages.nix.
  home.packages =
    with pkgs;
    [
      # IDEs
      jetbrains-toolbox

      # AI cli tools packaged in nixpkgs
      k8sgpt
      kubectl-ai
      cursor-cli
      qrtool
    ]
    ++ (lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      mitmproxy
      wireshark
      xeyes
      xvfb-run
    ])
    ++ (lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
      insomnia
    ]);
}
