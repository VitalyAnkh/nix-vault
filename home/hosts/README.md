# Host Home Modules

This directory contains host-specific Home Manager entry modules.

## Layout

- `home/hosts/linux/*.nix`: Linux host home modules
- `home/hosts/darwin/*.nix`: macOS host home modules

## Conventions

1. Each host output should reference only one file under `home/hosts/...`.
2. Shared home module imports should be handled in the host file itself.
   - Linux desktop hosts import `../../linux/gui.nix`; upstream's `agent` hosts (ruby, kana,
     aquamarine) import `../../linux/tui.nix`, see
     [Host Profiles](../../hosts/README.md#host-profiles).
   - Minimal standalone TUI hosts can instead import `../../base/core` and `../../base/tui` directly
     when they should avoid broader Linux-wide packages/services.
   - Darwin hosts import `../../darwin`.
3. Host-specific overrides (SSH keys, desktop toggles, host-local config links) live in the same
   host file.
