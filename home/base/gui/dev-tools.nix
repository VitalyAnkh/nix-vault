{
  lib,
  llm-agents,
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
    ++ (with llm-agents.packages.${pkgs.stdenv.hostPlatform.system}; [
      codex
      cursor-cli
      claude-code
      gemini-cli
      opencode
      rtk
    ])
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
