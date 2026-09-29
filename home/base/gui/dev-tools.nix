{
  lib,
  llm-agents,
  pkgs,
  ...
}:
let
  agentPackages = llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in
{
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
    ++ (with agentPackages; [
      # Codex is intentionally installed through pnpm, not Nix.
      grok
      kimi-code
      # `dsh` is the llm-agents package for DeepSeek Harness.
      dsh
      opencode
      orca
      pi
      omp
      zcode
    ])
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
