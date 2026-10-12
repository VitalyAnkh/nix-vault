{
  pkgs,
  llm-agents,
  ...
}:
let
  agentPackages = llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  home.packages = [
    # Agents
    # Codex is intentionally installed through pnpm, not Nix.
    # agentPackages.codex
    agentPackages.grok
    agentPackages.kimi-code
    # `dsh` is the llm-agents package for DeepSeek Harness. Upstream installs
    # nur-ryan4yin's dsh instead, which shims llm-agents' dsh for a nixpkgs
    # node it cannot boot on (node-addon-require-builtin probe):
    # nur-ryan4yin.packages.${pkgs.stdenv.hostPlatform.system}.dsh
    agentPackages.dsh
    agentPackages.opencode2
    agentPackages.pi

    # Docs lookup CLI behind the find-docs skill (agents/skills/find-docs). The skill's flags are
    # written against this package, not against upstream's npx instructions.
    pkgs.ctx7

    # MCP servers, configured project-scoped in opencode.jsonc / .codex/config.toml
    pkgs.mcp-grafana
  ];
}
