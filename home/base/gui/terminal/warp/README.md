# Warp settings

`modules.desktop.warp.enable` is off by default and enabled for astra, eva and muon. The module does
not install Warp: astra gets the `warp` cask from `hosts/darwin-astra/homebrew.nix`, and eva and
muon get the open-source build from
[pkgs/warp-terminal](../../../../../pkgs/warp-terminal/package.nix) through `hosts/eva/gnome.nix`
and `hosts/muon/gnome.nix`.

Warp keeps its settings in one TOML file, writes changes from its Settings UI back to it, and
applies edits to it while it runs:

| Platform | Settings file                                                                    |
| -------- | -------------------------------------------------------------------------------- |
| macOS    | `~/.warp/settings.toml`                                                          |
| Linux    | `$XDG_CONFIG_HOME/warp-oss/settings.toml`, the open-source build's app directory |

A Home Manager link would make that file read-only, so every activation merges the keys of
`modules.desktop.warp.settings` into it instead. All other settings stay Warp's. `settingsFile`
overrides the path, for example for stable Warp on Linux, which uses `warp-terminal` instead of
`warp-oss`.

## Owned settings

| Key                                                     | Value                                           | Reason                                                                                                                                                                                                   |
| ------------------------------------------------------- | ----------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `appearance.text.font_name`                             | `"Maple Mono NF CN"`                            | tuios and the Starship prompt draw Nerd Font icons. Warp uses one font without fallback, so a font without the icons shows `?` boxes. Ghostty and Zed use the same font, which gives CJK text two cells. |
| `global_hotkey.toggle_all_windows`                      | `enabled = true`, `keybinding = "ctrl-shift-E"` | Shows and hides all Warp windows. On macOS the Karabiner rules make it physical Caps Lock+Shift+E, see [Karabiner](../../../../darwin/karabiner/README.md).                                              |
| `session.new_session_shell_override.executable` (astra) | `"/opt/homebrew/bin/fish"`                      | Set in `home/hosts/darwin/darwin-astra.nix`, see [docs/astra-macos-host.md](../../../../../docs/astra-macos-host.md).                                                                                    |

The first two are module defaults (`lib.mkDefault`). A host can override them or own more keys,
using the names from Warp's settings schema
(`/Applications/Warp.app/Contents/Resources/settings_schema.json` on macOS):

```nix
modules.desktop.warp.settings.appearance.text.font_size = 15.0;
```

Nix keeps `15.0` a float and `15` an integer in the TOML it writes. Removing a key from the option
stops managing it; the file keeps the last value.

## How the file is written

`nix-vault-warp-sync`, also on `PATH`, runs after Home Manager's `writeBoundary`. A failure prints a
warning and leaves the rest of the activation alone; run the command again after fixing the cause.
It:

- refuses a symlink anywhere in the settings path, and a settings path that is not a regular file;
- changes only the lines of owned keys whose value differs, keeping each key as written and any
  comment after its value, appends missing keys to their table and missing tables at the end, and
  leaves every other byte and line ending as it was;
- parses the result and writes it only if it equals the previous settings with the owned values set,
  value types included. Dotted keys, inline tables or multi-line values at an owned key, which the
  line edits do not handle, stop the sync instead of being rewritten, and so does a line inside such
  a value elsewhere that looks like an owned key. Warp writes TOML 1.1 (inline tables across lines,
  with trailing commas), which the standard library's `tomllib` cannot read, so the sync uses
  `tomli` ([python.nix](./python.nix));
- does not rewrite or back up a file that already holds the owned values;
- checks that the file did not change while the replacement was prepared, saves the previous file as
  `settings.toml.nix-vault-backup-TIMESTAMP-*`, and replaces the file atomically. Backups contain
  the complete previous file and are not pruned. A new file gets mode 0600; an existing file keeps
  its mode.

`nix-vault-warp-sync --verbose` applies the settings of the current generation again, for example
after an owned value was changed in Warp's Settings UI.

## Verification

Building the sync runs its unit tests on the build platform (`nix-vault-warp-sync-tests`), so every
build of astra, eva or muon tests it on macOS or Linux. `just warp-test` runs the same tests with
the same Python, built from [python.nix](./python.nix) with the flake's nixpkgs:

```sh
just warp-test
```

They cover first runs, line-preserving updates next to TOML 1.1 inline tables, appended keys and
tables, idempotence, comments and CRLF line ends, value types and escapes, refused file shapes and
settings, a line inside an inline table that looks like an owned key, symlinks, concurrent edits, a
failed replacement and the default path on both platforms. They do not start Warp. The eval tests
check, for astra in `outputs/aarch64-darwin/tests/astra` and for eva and muon in
`outputs/x86_64-linux/tests/warp-settings`, the owned settings and the path, that no Home Manager
link manages the file, that the sync runs after `writeBoundary` and only warns on failure, and that
the named font is installed; on astra also that the session shell is the declared Homebrew Fish, and
on eva and muon that `~/.config/warp-oss` is preserved and Warp OSS is installed.

After a switch, `nix-vault-warp-sync --verbose` reports `Already up to date`, and Warp shows the
values in its Settings. Warp shows a banner when it cannot use a value from the file.

Reference: [Warp settings file](https://docs.warp.dev/terminal/settings/).
