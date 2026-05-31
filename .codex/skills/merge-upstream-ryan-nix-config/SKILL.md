---
name: merge-upstream-ryan-nix-config
description: >-
  Merge upstream ryan/main into the current checkout's local vr branch. Use when Codex must fetch or
  integrate ryan/main, resolve Nix/NixOS flake conflicts, preserve local vr customizations, migrate
  upstream idols-ai or ai host changes into eva, reconcile flake.lock and other lock files, and
  verify eva/muon/package invariants for this Nix config.
---

# Merge Upstream Ryan Nix Config

## Overview

Use this workflow from the current repository checkout when merging upstream `ryan/main` into local
`vr`. Do not assume the checkout lives at a fixed filesystem path. Optimize for preserving both
sides: keep upstream fixes where safe, keep local customizations where they are intentional, and
document any deliberate non-migration.

## Start With Evidence

1. Read the repository `AGENTS.md` merge rules and any active planning files.
2. Use `planning-with-files` for non-trivial merges: keep `task_plan.md`, `findings.md`, and
   `progress.md` current, but do not stage them unless explicitly requested.
3. Inspect `git status --short --branch` before touching anything. If unrelated tracked changes
   exist, preserve them by understanding, stashing, or working around them; never discard them.
4. Fetch `ryan/main` into the remote-tracking ref that later commands read, identify the last merge
   base, and read commit messages on both sides before resolving conflicts:

```bash
git fetch ryan refs/heads/main:refs/remotes/ryan/main
git rev-parse --verify refs/remotes/ryan/main
git log --oneline --decorate <last-merge-or-base>..refs/remotes/ryan/main
git log --oneline --decorate --first-parent <last-merge-or-base>..HEAD
git merge-tree HEAD refs/remotes/ryan/main
```

Do not replace the explicit refspec with a fetch form that omits the destination ref; that can
update only `FETCH_HEAD` while leaving `ryan/main` stale or absent. Use the commit messages as
intent, not as proof. Confirm with diffs and the current tree.

## Preservation Rules

Preserve these local `vr` customization lines unless the user explicitly asks otherwise or
verification proves they must change:

- Local package pipeline under `pkgs/`, including generated `_sources`, `nvfetcher`,
  `callPackageFromDirectory`, and packages defined under `pkgs/` rather than Ryan's overlay layer.
- Codex Desktop package and Home Manager/NixOS wiring, including computer-use, ydotool/uinput
  behavior, desktop portal screenshot wrapper, and persisted Codex Desktop state.
- `emacs-master-pgtk-with-igc`, Doom Emacs activation/config wiring, and Home Manager references to
  the local Emacs build.
- Local fcitx5/Rime setup and data packages. Do not replace it with upstream Rime defaults unless
  requested.
- Nutstore packages and Nautilus integration.
- Local `eva` boot, disk, filesystem, activation, and preservation semantics.
- `muon` as a light customization of `eva`, including its multi-user additions and host-local
  overrides.

Prefer migration over deletion when upstream changes overlap a local successor. If an upstream
improvement is safe but targets a renamed or replaced local component, port it to the local
component instead of ignoring it.

## Host Lineage

Treat upstream `idols-ai` / `ai` host changes as source lineage for local `eva`.

- Compare upstream `hosts/idols-ai`, `home/hosts/linux/idols-ai.nix`, and related output files
  against local `hosts/eva`, `home/hosts/linux/eva.nix`, and `outputs/x86_64-linux/src/eva.nix`.
- Migrate safe upstream host improvements into `eva`, especially AI-agent state, desktop state,
  service defaults, preservation paths, and non-disruptive comments/docs.
- Preserve `eva` boot/storage/preservation contracts unless the user explicitly asks for a change.
- If upstream removes a preserved user state path such as `.gemini` or `.kimi`, do not automatically
  remove the local `eva` path. Removing a preserved path can hide existing `/persistent` data after
  activation; keep it or record why removal is safe.
- If an upstream `ai-niri` output is stale in the local tree because `eva` is the successor, remove
  or disable the stale output only after confirming `eva` / `eva-niri` still evaluate.

## Lockfile Strategy

For `flake.lock`, `uv.lock`, generated sources, and similar lock files:

1. Do not blindly take either side.
2. Prefer newer compatible hashes when both sides update the same input.
3. If upstream removes an input from `flake.nix`, remove the matching lock nodes by reconciling or
   regenerating the lock from the merged `flake.nix`.
4. Preserve local package-source refreshes that support `pkgs/`, Codex Desktop, Emacs, fcitx5,
   Nutstore, or other local package plumbing.
5. Verify the chosen lock with actual Nix evaluation/builds. Do not keep a newer hash that breaks
   required local validation.

When regenerating `flake.lock`, stage any new flake-visible files first; flakes do not see untracked
files.

## Conflict Resolution

Use this conflict order:

1. Resolve structural conflicts in `flake.nix` and outputs first.
2. Resolve package/input plumbing while preserving the local `pkgs/` pipeline.
3. Resolve host/Home Manager conflicts, migrating upstream `idols-ai` changes into `eva`.
4. Resolve lock files after the merged input graph is coherent.
5. Resolve formatting/generated metadata last.

For each conflict, record the decision in `findings.md`: upstream intent, local customization, final
resolution, and verification needed.

If upstream removes a feature that local `vr` had, distinguish between:

- Upstream cleanup that should be followed, such as a removed dependency the user accepts.
- Local customization that must remain, such as package pipeline, input method, Emacs, Nutstore, or
  `eva` storage semantics.

Ask only when the choice is materially branching and cannot be inferred from local rules.

## Verification Gates

Run the strongest feasible checks before claiming completion.

Static checks:

```bash
git diff --check
git diff --cached --check
rg -n "^<<<<<<<|^=======|^>>>>>>>" . --glob '!task_plan.md' --glob '!findings.md' --glob '!progress.md' --glob '!.omx/**'
```

Targeted scans depend on the merge. For example, after AAGL removal:

```bash
rg -n "aagl|anime-game-launcher|honkers-railway-launcher|sleepy-launcher|mihoyo-telemetry" . --glob '!task_plan.md' --glob '!findings.md' --glob '!progress.md' --glob '!.omx/**'
```

Evaluate host and package invariants:

- Confirm `eva` file systems, root device, `/persistent` UUID, `preservation.preserveAt`, kernel
  params, blacklisted modules, and persisted user paths.
- Confirm `muon` keeps its intended role and shared safe `eva` behavior.
- Confirm local package pipeline still exposes/builds key packages: `codex-desktop`,
  `emacs-master-pgtk-with-igc`, `fcitx5-rime`, `gnome-screenshot-portal`, `nutstore-client`, and
  `nutstore-nautilus`.
- Confirm removed upstream inputs are really absent when removal is intended.

Standard Nix checks:

```bash
nix flake check --no-build --impure
nixos-rebuild build --impure --flake .#eva
```

If full `eva` build fails on an unrelated source/substitute/package-test issue, capture the exact
derivation and error. Prefer a narrow compatibility fix when it is local and reviewable; otherwise
report the external blocker without calling the configuration verified.

## Finalization

Before committing or reporting:

1. Confirm there are no conflict markers.
2. Confirm new flake-visible files are staged before final Nix evaluation.
3. Confirm planning files, `.omx/`, `.direnv/`, `result` links, `.venv`, `uv.lock` byproducts, and
   other process artifacts are not accidentally staged unless explicitly requested.
4. If the task requests a completed merge, create a merge commit only after verification. Use a
   commit message that names upstream changes, migrated `eva` behavior, preserved local pipelines,
   and any compatibility fixes.
5. Leave any unrelated stash intact and report it.

Final reports should state:

- Upstream commits or themes merged.
- What was migrated into `eva`.
- What local customization was preserved.
- Any deliberate upstream change not adopted and why.
- Exact verification commands and outcomes, especially `nix flake check --no-build --impure` and
  `nixos-rebuild build --impure --flake .#eva`.
