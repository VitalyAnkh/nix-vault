{
  lib,
  llm-agents,
  magpie,
  pkgs,
  ...
}:
let
  agentPackages = llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  # magpie sends a daily usage event (an install id, its version and the ids of
  # the agents, providers and models it is used with) unless told not to; like
  # the other agent opt-outs in home/base/tui/agents/env.nix. Set for the
  # systemd user manager as well, since the desktop app is started from the
  # app grid, not from a login shell.
  magpieEnv.MAGPIE_NO_STATS = "1";
in
{
  home.sessionVariables = lib.mkIf pkgs.stdenv.hostPlatform.isLinux magpieEnv;
  systemd.user.sessionVariables = lib.mkIf pkgs.stdenv.hostPlatform.isLinux magpieEnv;

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
      # magpie's desktop app (window, tray, TUI, web UI and CLI in one
      # `magpie` binary), from its own release flake: llm-agents does not
      # package it. Its state is ~/.config/magpie, keys included.
      magpie.packages.${pkgs.stdenv.hostPlatform.system}.magpie
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
