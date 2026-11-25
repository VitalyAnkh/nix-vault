# Agents

Home Manager module that owns the Nix side of the AI coding agents: deploying the global rules and
custom global skills, the agent CLIs, and their environment.

The canonical rules text, local skills, behavioral scenarios, and external-tool snippets live in the
top-level [`agents/`](../../../../agents/README.md) directory. That directory stays portable
Markdown with no Nix dependency; this module only wires it into place.

## Files

- `rules.nix`: links the global rules to every agent's config location. Off unless
  `modules.agents.globalRules.enable` is set: these hosts keep `~/.codex/AGENTS.md` and the other
  rule files user-managed (oh-my-codex writes its own).
- `skills.nix`: links the global skills into `~/.agents/skills/<name>`, from pinned flake inputs and
  from `agents/skills/`; the inventory is
  [agents/skills/README.md](../../../../agents/skills/README.md). Off unless
  `modules.agents.skills.enable` is set, for the same reason.
- `packages.nix`: agent CLIs (`grok`, `kimi-code`, `dsh`, `opencode`, `pi`, `antigravity-cli`) from
  the `llm-agents` flake input, plus `pkgs.ctx7` (the find-docs skill's CLI) and `pkgs.mcp-grafana`
  (the Grafana MCP server). `opencode` is llm-agents' `opencode2` (OpenCode V2) under its normal
  command name. Codex is installed through pnpm instead. The desktop agent apps (`antigravity-hub`
  on every platform; `grok-bot`, `orca`, `zcode` on Linux) are installed by the GUI layer,
  `home/base/gui/dev-tools.nix`, together with magpie (Linux), which llm-agents does not package and
  which comes from its own release flake input, `magpie`.
- `env.nix`: telemetry and auto-update opt-outs for the agents. magpie's (`MAGPIE_NO_STATS`) sits
  beside its package in `dev-tools.nix`, also set for the systemd user manager so that the app
  started from the desktop sees it.

dsh is installed by this module (the `llm-agents` build; upstream uses nur-ryan4yin's shim) but
configured at runtime, not by Nix: profile patches live in
`~/.dsh/profiles/<name>/cordis.patch.yml`. See [dsh.md](./dsh.md) for the layer order and the
settings that bite.

## magpie

[magpie](https://github.com/yetone/magpie) picks which model each agent on the machine talks to and
runs one local gateway for all of them. llm-agents does not package it, so the `magpie` flake input
points at its own release flake (`github:yetone/magpie-releases`), which wraps the project's signed
release binaries; nothing is compiled, and the pin moves with `nix flake update magpie`. One
`magpie` binary is the window, the menu-bar icon, the TUI (`magpie tui`), the web UI and the CLI.
All of its wiring is `home/linux/gui/base/magpie.nix` (`modules.desktop.magpie`), Linux-only.

A magpie that runs from `/nix/store` leaves updating to Nix instead of replacing its own binary.

Installing it starts nothing and reaches nothing: the gateway has no models until
`magpie provider add <preset> <key>` or a subscription sign-in on the Providers page.

### The user service and the autostart entry

magpie can put itself in two places that Home Manager owns, so the module declares both instead:

| Option                             | File it owns                            | Equivalent command      |
| ---------------------------------- | --------------------------------------- | ----------------------- |
| `modules.desktop.magpie.daemon`    | `~/.config/systemd/user/magpie.service` | `magpie daemon install` |
| `modules.desktop.magpie.autostart` | `~/.config/autostart/magpie.desktop`    | `magpie autostart on`   |

Do not run those two commands on these hosts: the files are read-only store symlinks, and neither
directory is preserved, so anything magpie wrote there by hand is lost at the next boot anyway.
`magpie daemon status`, `restart`, `stop` and `start` keep working, as does
`systemctl --user restart magpie`.

**The two are mutually exclusive**, and the module asserts it. Both serve the gateway, and it binds
a fixed loopback port (127.0.0.1:3425), so the pair would take turns failing on it; upstream's own
`daemon install` refuses to run while autostart is on.

eva runs the service (`daemon.enable`), because GNOME has no tray there and an autostarted
`magpie tray` would be an invisible process; the window opened from the app grid reuses the running
gateway. The service is off by default for the hosts several people share: one fixed port cannot
serve a service per logged-in user, so on muon the second user's would find it taken. Without
`users.users.<name>.linger = true` on the host, systemd starts the service at the user's first login
rather than at boot.

Two details that cost a measurement, so do not re-derive them by guessing:

- the autostart entry runs `magpie tray` (the menu-bar icon alone), **not** the `magpie %u` of the
  package's own desktop entry, which opens the window as well;
- magpie writes the path of the build it ran from into the entries it creates -- a store path, which
  a garbage collection removes after an upgrade. The declared entry is rewritten by every switch and
  kept alive by the generation that owns it.

The service's `Environment=` carries only `PATH`, spelled out because the user manager's own PATH is
imported from the graphical session at login and would be missing from a unit that starts at boot.
Keep credentials out of it: upstream makes its generated unit readable by its owner alone because
the environment it captures can hold a proxy password, while a unit in the store is world-readable.
magpie reads its own secrets from the 0600 files below.

### State

`~/.config/magpie` is deliberately flat: `providers.json` (API keys), `logins.json` and
`plugin-auth.json` (subscription sign-ins), `caller-keys.json` -- all 0600 -- plus `settings.json`,
the usage and routing history, and `stash.json`/`applied.json`, which record what magpie changed in
each agent's own config and are what it needs to put those settings back. It is preserved on the
tmpfs-root hosts (`hosts/eva/preservation.nix`); `~/.cache/magpie` (the Bun it runs plugins on,
model catalogs) and `~/.local/state/magpie/app.log` fall under the already preserved `.cache` and
`.local/state`.

Never copy `~/.config/magpie` to another machine: the keys and sign-ins in it are per machine, and
`install-id` identifies this one.

magpie sends one usage event a day (an install id, its version, and the ids of the agents, providers
and models in use). The module sets `MAGPIE_NO_STATS = "1"` to turn that off, in both
`home.sessionVariables` and `systemd.user.sessionVariables`, because magpie is started from the
desktop or by its user unit rather than from a login shell.

## Deployed rule targets

`rules.nix` creates one out-of-store symlink per target, all pointing at
`${repoRoot}/agents/global-rules.md` (the host's configured checkout root):

| Agent      | Target                         |
| ---------- | ------------------------------ |
| Codex      | `~/.codex/AGENTS.md`           |
| OpenCode   | `~/.config/opencode/AGENTS.md` |
| Pi         | `~/.pi/agent/AGENTS.md`        |
| Cross-tool | `~/.agents/AGENTS.md`          |
| dsh        | `~/.dsh/AGENTS.md`             |

dsh reads both `~/.dsh/AGENTS.md` (`$DSH_HOME`) and, from `0.2.1-alpha.2` on, `~/.agents/AGENTS.md`
(`$DSH_AGENTS_HOME`); identical content renders once.

Out-of-store means an edit to `agents/global-rules.md` takes effect on the next agent session
without a Home Manager switch. The trade-off is that the rules stay writable in the checkout; use a
store symlink (`home.file.<target>.source = ../../../../agents/global-rules.md`) if immutability
matters more than fast iteration.

## Global skills

`skills.nix` links every directory under `agents/skills/` out-of-store, so an edit applies on the
next session, and the skills selected from pinned flake inputs as store paths, which change only
with a lock bump and a switch. Home Manager's normal collision checks apply: do not force
replacement of an existing same-name skill, and do not install global skills with
`npx skills add -g` alongside these links.

The installed releases support the shared root and symlinked skill directories, so no agent-specific
compatibility links are needed:

- **Codex**: [Skill documentation](https://learn.chatgpt.com/docs/build-skills.md) lists
  `~/.agents/skills` and symlinked skill folders.
- **OpenCode**:
  [v2.0.22 discovery](https://github.com/anomalyco/opencode/blob/v2.0.22/packages/core/src/config/discovery.ts)
  includes the global `.agents` root; its
  [compatibility loader](https://github.com/anomalyco/opencode/blob/v2.0.22/packages/core/src/config/plugin/compatibility.ts)
  follows skill symlinks.
- **Pi**:
  [v1.0.1 discovery](https://github.com/badlogic/pi-mono/blob/v1.0.1/packages/coding-agent/src/core/package-manager.ts)
  includes `~/.agents/skills` and follows symlink directories.
- **dsh**:
  [Filesystem skill package](https://www.npmjs.com/package/@deepseek-ai/dsh-skill-filesystem)
  documents `~/.agents/skills` and directory symlinks; confirmed in the shipped 0.2.0-rc.2 loader.

Adding or removing links requires a user-run Home Manager switch. Changes to an already-linked skill
are available without a rebuild; start a new session or use the harness's reload mechanism to read
them. After activation, verify the link target and that `git-delivery` appears in the skill catalog.
Custom root overrides or disabled discovery still need runtime configuration.

The rules include a direct checkout fallback for `git-delivery` before its link is installed.
Runtime permissions are not managed by this module.
