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
      grok
      kimi-code
      orca
      zcode
      #codex
      #claude-code
      #opencode
      #rtk
    ])
    ++ (lib.optionals stdenv.hostPlatform.isLinux [
      mitmproxy # http/https proxy tool
      wireshark # network analyzer
      qrtool # decode/encode qr code

      xeyes
      xvfb-run
    ])
    ++ (lib.optionals stdenv.hostPlatform.isx86_64 [
      insomnia # REST client
    ]);
}
