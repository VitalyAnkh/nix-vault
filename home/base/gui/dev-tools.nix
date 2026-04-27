{
  lib,
  llm-agents,
  pkgs,
  ...
}:
let
  llmAgentPackages = llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  home.packages =
    with pkgs;
    [
      # IDEs
      jetbrains-toolbox

      # AI cli tools
      k8sgpt
      kubectl-ai # an ai helper opensourced by google
      cursor-cli # packaged in nixpkgs, not llm-agents
    ]
    ++ (with llmAgentPackages; [
      #codex
      #claude-code
      #gemini-cli
      #opencode
      #rtk
    ])
    ++ (lib.optionals stdenv.isLinux [
      mitmproxy # http/https proxy tool
      wireshark # network analyzer

      xeyes
      xvfb-run
    ])
    ++ (lib.optionals stdenv.isx86_64 [
      insomnia # REST client
    ]);
}
