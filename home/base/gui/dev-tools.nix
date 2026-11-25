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
  # Agent CLIs from llm-agents live in home/base/tui/agents/packages.nix; the
  # desktop agent apps stay here, out of the TUI-only configurations.
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

      # Antigravity desktop app (`antigravity`, Antigravity.app on macOS). The
      # Antigravity IDE is a separate package, pkgs.antigravity-ide.
      agentPackages.antigravity-hub
    ]
    # These llm-agents desktop apps are Linux-only upstream.
    ++ (lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      agentPackages.grok-bot
      agentPackages.orca
      agentPackages.zcode
      # magpie is the fourth of these, but llm-agents does not package it and
      # it owns a user service and an autostart entry, so all of its wiring
      # lives in home/linux/gui/base/magpie.nix instead.
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
