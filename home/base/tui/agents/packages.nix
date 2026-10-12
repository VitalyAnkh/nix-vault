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
    agentPackages.codex
    agentPackages.opencode2
    agentPackages.pi
    # Keep the llm-agents package set coherent with grok-bot and the other
    # agent CLIs; the current flake exports dsh directly.
    agentPackages.dsh

    # Docs lookup CLI behind the find-docs skill (agents/skills/find-docs). The skill's flags are
    # written against this package, not against upstream's npx instructions.
    pkgs.ctx7

    # MCP servers, configured project-scoped in opencode.jsonc / .codex/config.toml
    pkgs.mcp-grafana
  ];
}
