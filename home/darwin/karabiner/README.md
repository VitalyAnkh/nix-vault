# Karabiner-Elements rules

`modules.desktop.karabiner.enable` is off by default and enabled for Astra. It installs a rule asset
and a configuration sync helper through Home Manager. Karabiner-Elements itself comes from the
`karabiner-elements` cask, which runs the official macOS package; Astra declares it in
`hosts/darwin-astra/homebrew.nix`. This module does not enable Homebrew.

On a host that does not declare the cask, install the app from the
[official download](https://karabiner-elements.pqrs.org/) or with
`brew install --cask karabiner-elements`. Complete the app's setup for background services,
Accessibility/Input Monitoring, and its virtual HID driver. The configuration alone cannot grant
those permissions.

## Mappings

Both profiles exchange Caps Lock and left Control on **every keyboard** that Karabiner modifies,
built-in and external alike: Caps Lock (中/英) becomes left Control, and left Control becomes Caps
Lock. Right Control keeps its role, and devices that are not keyboards are unaffected. The rule
matches `device_if` with `is_keyboard`, so a newly connected keyboard behaves the same without
per-device settings. Ctrl below means the resulting logical Control key, so use the physical Caps
Lock key. Physical left Control then behaves as Caps Lock, including its LED and, with the macOS
setting for Chinese input sources, switching to and from ABC.

A keyboard whose firmware already exchanges these keys, for example with a DIP switch, would be
exchanged twice. Turn the hardware exchange off so that Karabiner stays the only place for it, or
add a `device_unless` condition with the keyboard's `vendor_id` and `product_id` to both
manipulators. `karabiner_cli --list-connected-devices` shows these identifiers.

On the **built-in keyboard** only, both profiles also exchange Command and Option on both sides, as
Astra's macOS settings for that keyboard do. The key next to the space bar becomes Option, which
Emacs reads as Meta, and the physical Option key becomes Command, which Emacs reads as Super. As on
a PC keyboard under Linux, Meta (Alt) is then next to the space bar, Super beside it, and Control on
the Caps Lock key. External keyboards keep their Command and Option keys; a PC-layout keyboard
already has Option (Alt) next to the space bar. The rule matches `device_if` with
`is_built_in_keyboard`, which `karabiner_cli --list-connected-devices` reports for the MacBook
keyboard, a device without vendor and product IDs. Karabiner also counts a keyboard as built-in when
its **Treat as a built-in keyboard** device setting is on in the selected profile. Keep this
exchange in the rule alone: a Karabiner simple modification for these keys on the built-in keyboard
would exchange them a second time, and a macOS modifier-key setting for the Karabiner virtual
keyboard would apply to the output of every keyboard.

Like Ctrl, Command and Option below mean the resulting logical keys. On the built-in keyboard, macOS
Command shortcuts such as Command+Tab and Command+Space use the physical Option key, and the
physical Command key with a letter types Option characters, such as `ç`, in text fields. Doom Emacs
leaves right Option to macOS for composing characters (`ns-right-option-modifier` is `none`), so in
Emacs only the left key next to the space bar is Meta, and the right one composes characters.
Setting `ns-right-option-modifier` to `left` in the Doom configuration makes the right one Meta as
well.

The **Nix Vault - Linux shortcuts** profile keeps Command shortcuts and adds these exact
combinations (either Control/Shift side, Caps Lock allowed):

| Context          | Input                        | Output                            |
| ---------------- | ---------------------------- | --------------------------------- |
| Allowed GUI apps | Ctrl+C/V/X/Z/A/S/F/W/T/N/O/P | Command + the same key            |
| Allowed GUI apps | Ctrl+Shift+Z                 | Command+Shift+Z (redo)            |
| Warp             | Ctrl+Shift+C / Ctrl+Shift+V  | Command+C / Command+V             |
| Warp             | Ctrl+Shift+Z                 | Command+Z (Warp input undo)       |
| Warp             | Ctrl+Shift+Y                 | Command+Shift+Z (Warp input redo) |

The GUI allowlist is Finder, Safari, Chrome, Edge, TextEdit, Preview, Notes, Mail, Lark, Telegram,
WeChat, WPS Office, and Obsidian. The JSON contains anchored, exact bundle identifiers. Adding an
app requires adding its identifier to each GUI manipulator and to `GUI_APPS` in the tests, which
check that every copy matches.

Emacs, VS Code, Zed, other IDEs, Codex, terminals, SSH clients, and remote desktop clients receive
no generic mapping. Warp (`dev.warp.Warp-Stable`) has only the four explicit combinations above: raw
Ctrl+C/Z/A/E/V and Option/Meta stay unchanged. The shared Zellij configuration is unchanged. Extra
Option, Command, Fn, or Shift modifiers are not absorbed by the GUI shortcuts; redo is the explicit
exception. Separately from these shortcuts, the [Emacs hotkey](#emacs-hotkey) takes Ctrl+Shift+Q in
every app, including those listed here, and in both profiles.

App matching cannot distinguish a web page, embedded terminal, remote session, or editor inside an
allowed app. Select **Nix Vault - Native** before using browser terminals or any app content that
needs native Control keys. This also provides a quick fallback through Karabiner Settings → Profiles
or its menu-bar profile menu. Native keeps both modifier exchanges and the Emacs hotkey, without the
GUI or Warp shortcut additions. Sync preserves any separate rules you add there. Applications may
have different meanings for the resulting Command shortcut (for example, Finder's Command+X is not
file cut). In the allowed apps, the macOS Emacs-style text bindings Ctrl+A (line start), Ctrl+F/N/P
(forward, down, up), Ctrl+O (open line), Ctrl+T (transpose) and Ctrl+V (page down) no longer reach
text fields; the others, such as Ctrl+E/B/K/D/H, still work.

## Emacs hotkey

Both Nix Vault profiles toggle Emacs with **Ctrl+Shift+Q** in every app:

- When Emacs is not the frontmost app, the shortcut opens
  `~/Applications/Home Manager Apps/Emacs.app`, the copy that Home Manager's `copyApps` maintains.
  It launches Emacs, or activates the running instance and shows its frames, as clicking its Dock
  icon does.
- When Emacs is frontmost, it sends Command+H, which Emacs binds to `ns-do-hide-emacs` by default.
  Emacs hides all its frames, and the previously active app returns, like Warp's global hotkey.

As above, Ctrl is the logical Control key: press the physical Caps Lock key with either Shift and Q.
Physical left Control is Caps Lock and does not trigger it. Caps Lock may be on, and holding the
keys does not repeat the action. Combinations with additional Command, Option, or Fn keys pass
through, including macOS's Lock Screen (Control+Command+Q) and Log Out (Shift+Command+Q).

The rule uses `software_function.open_application` with a `file_path` rather than the
`org.gnu.Emacs` bundle identifier. The store's Emacs.app and Home Manager's copy share that
identifier and version, and LaunchServices does not reliably register the copy, so a lookup by
bundle identifier could open either. The asset contains a path that starts with `~/`; sync resolves
it against `--home`, the current user's home directory by default, and warns when the resulting app
does not exist. Karabiner itself reports nothing for a missing app: the key is consumed and nothing
happens. Because the rule depends on them, the module asserts that Emacs is enabled without its
daemon and that `copyApps` uses its default directory.

Limitations:

- The shortcut works only while Karabiner grabs the keyboard. Shortly after wake, during an update,
  or after Karabiner-Elements was quit, Ctrl+Shift+Q reaches the frontmost app: kitty closes the
  current tab, and Emacs starts `quoted-insert`. If the shortcut and the GUI shortcuts stay inactive
  after wake, restart Karabiner-Elements from its Settings.
- Emacs started outside its app bundle, such as `bin/emacs` from a shell or an Emacs daemon, is a
  different app: the shortcut opens Emacs.app as another instance.
- macOS treats activation as a request. An opened app can occasionally stay behind the current one,
  and keys typed immediately after the shortcut can still reach the previous app.
- Hiding relies on Emacs's default Command+H binding. If an Emacs configuration maps Command to Meta
  (`ns-command-modifier`) or rebinds `s-h`, change the rule's first manipulator.
- Hiding is an ordinary Emacs command (`s-h`). While a prefix key is pending, Command+H completes
  that key sequence instead: after `C-x`, `C-c` or `C-h` Emacs reports, for example,
  `C-x s-h is undefined`, and after a pending ESC it becomes `M-s-h`, `ns-do-hide-others`, which
  hides all other apps and leaves Emacs in front. While an input method is composing text, Emacs
  passes a plain `h` to the input method. Press `C-g` or commit the text first. A busy Emacs hides
  after the current command finishes.
- Karabiner's conditions see only which app is active, not whether it has visible windows. If Emacs
  stays active after its only frame was minimized (Command+M or `C-z`), the first Ctrl+Shift+Q hides
  it; press it again, or click its Dock icon, to show the frame.
- Like Emacs opened from the Dock or Spotlight, Emacs opened this way gets launchd's PATH rather
  than the shell's.

## Apply just this configuration

From the repository root, without activating the whole nix-darwin host:

```sh
python3 home/darwin/karabiner/sync.py --select
```

After this Home Manager module has been activated, the equivalent command is
`nix-vault-karabiner-sync --select`. Omit `--select` when updating rules while keeping the current
profile. An empty first configuration selects Linux shortcuts; an existing configuration retains its
selection unless explicitly requested.

The helper uses `$XDG_CONFIG_HOME/karabiner/karabiner.json` or `~/.config/karabiner/karabiner.json`.
`--config PATH`, `--rules PATH` and `--home PATH` support isolated checks. Home Manager's wrapper
uses its configured `xdg.configHome` and `home.homeDirectory`. The active JSON stays a mutable,
regular file: Karabiner can rewrite and reload it. Only the asset under
`karabiner/assets/complex_modifications/` is a store symlink. Do not manually enable that asset in
other profiles if you want them to stay native.

Sync owns the **Nix Vault - Linux shortcuts** profile's rules whose descriptions start with
`Nix Vault: `. In **Nix Vault - Native**, it owns the exact rule `Nix Vault: Caps Lock and Control`
and the rules whose descriptions start with `Nix Vault: All profiles: `, such as the built-in
keyboard's Command/Option exchange and the Emacs hotkey; a shared rule removed from the asset is
removed from both profiles. When an owned rule is renamed, add its earlier description to
`RENAMED_RULES` in `sync.py`: sync then replaces a saved rule with that description in place, as the
current rule, and keeps its enabled state. Edits inside owned rules are replaced, but a rule
switched off in Karabiner Settings stays off in that profile. Other settings, devices, profiles, and
separate user rules are preserved; new owned rules are appended and existing owned rules are
replaced in place. A newly created profile copies the selected profile's `virtual_hid_keyboard`
settings (such as the ANSI/ISO/JIS keyboard type), while its other settings start with Karabiner
defaults. The helper validates JSON, refuses symlinks in the active configuration path, checks for
concurrent edits, saves the previous file as `karabiner.json.nix-vault-backup-TIMESTAMP-*`, and
replaces the file atomically. Unchanged configurations, including Karabiner's own normalized
rewrites, are not rewritten or backed up. Backups contain the complete previous configuration and
can be copied back if needed; they are not pruned automatically.

Home Manager runs the same helper after `writeBoundary` and `copyApps`, without changing profile
selection, so that its warning about a missing app reflects the new copy. It prints only when it
changes the file or an app is missing, unless activation runs verbosely. If the sync refuses the
current file, activation prints a warning and continues; the file stays unchanged until
`nix-vault-karabiner-sync` succeeds. Turning the module off stops future synchronization; the
mutable JSON remains, including the Emacs hotkey in both profiles, which the module's assertions no
longer protect. If Emacs is later disabled or run as a daemon, or `copyApps` is disabled or moved,
delete `Nix Vault: All profiles: Emacs global hotkey` from both Nix Vault profiles in Karabiner
Settings; otherwise Ctrl+Shift+Q stays consumed in every app and opens nothing or a stale copy.
Select Native to stop the additional GUI/Warp shortcuts while retaining both modifier exchanges and
the Emacs hotkey.

## Existing shortcuts after installation

Karabiner forwards input from every keyboard it modifies through its virtual keyboard, so the macOS
modifier-key settings of a physical keyboard do not apply to it. Astra's macOS settings exchange
Caps Lock and Control on its keyboards, and Command and Option on the built-in keyboard. The two
Karabiner rules reproduce these exchanges, except that right Control stays Control: the macOS
Control key setting also turns right Control into Caps Lock. Without the Caps Lock rule, the
physical Caps Lock key stays Caps Lock: pressing it with Shift+8, meant as Control+Shift+8 (select
the previous input source), switches the input language through Caps Lock while Shift+8 types `*`.
With the rule, Ctrl+Shift+8 and Ctrl+Shift+E pass through as Control combinations; no input-source
shortcut is rebound or translated by this module. Without the Command/Option rule, the built-in key
next to the space bar stays Command, and Emacs commands such as `M-o`, `M-.` and `M-,` need the
physical Option key. Keep these macOS settings: they apply when Karabiner is not running or when a
device's **Modify events** setting is off. A profile without these rules, such as Karabiner's
**Default profile**, gives the physical layout, because the macOS settings do not apply there
either.

Warp's global hotkey lives in `~/.warp/settings.toml`, which this module does not manage. With these
rules active, Ctrl+Shift+E (physical Caps Lock+Shift+E) toggles all Warp windows when the file
contains:

```toml
[global_hotkey.toggle_all_windows]
enabled = true
keybinding = "ctrl-shift-E"
```

Warp's shortcut syntax requires the uppercase letter with Shift, and Warp reloads the file when it
changes. Correct the modifier mapping before recording a shortcut in Warp's settings, then verify
the recorded combination.

## Verification

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s home/darwin/karabiner -p 'test_*.py' -v
"/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli" \
  --lint-complex-modifications home/darwin/karabiner/linux-shortcuts.json
```

Tests cover app/modifier matching, keyboard and device matching, modifier propagation, Native
behavior, terminal controls, the Emacs hotkey and its application path, and isolated configuration
updates, backups, idempotence, selection, renamed and shared rules, and failure handling. The lint
uses Karabiner's own validator; it does not check that application paths exist. Neither proves that
macOS permissions or the virtual HID driver are active. Synthetic events may bypass Karabiner's
physical keyboard path. On each keyboard, verify physical Caps Lock → Control and left Control →
Caps Lock first. On the built-in keyboard, also verify on both sides that the key next to the space
bar gives Option and the physical Option key gives Command, while an external keyboard keeps both
keys; in Emacs, `M-o`, `M-.` and `M-,` then use the key next to the space bar. Then check Ctrl+C/V
and undo/redo in a GUI app, Ctrl+Shift+C/V/Z/Y in Warp, raw Ctrl+C/Z in Warp and Zellij, and the
existing input-language and Warp global shortcuts. For the Emacs hotkey, press Ctrl+Shift+Q in
another app with Emacs not running, behind other windows, hidden, and minimized, then again with
Emacs frontmost, including with Emacs still active after its only frame was minimized.
`pgrep -lf 'Emacs\.app/Contents/MacOS/Emacs'` prints one line per running Emacs.app with its path:
it should be under `Home Manager Apps`, and a second line means another copy runs. EventViewer and
actual app behavior provide runtime evidence.

References:
[frontmost application conditions](https://karabiner-elements.pqrs.org/docs/json/complex-modifications-manipulator-definition/conditions/frontmost-application/),
[modifier matching](https://karabiner-elements.pqrs.org/docs/json/complex-modifications-manipulator-definition/from/modifiers/),
[built-in device conditions](https://karabiner-elements.pqrs.org/docs/json/complex-modifications-manipulator-definition/conditions/device/),
[open_application](https://karabiner-elements.pqrs.org/docs/json/complex-modifications-manipulator-definition/to/software_function/open_application/),
[key repeat of to events](https://karabiner-elements.pqrs.org/docs/json/complex-modifications-manipulator-definition/to/repeat/),
[macOS modifier settings and the virtual keyboard](https://github.com/pqrs-org/Karabiner-Elements/issues/4461#issuecomment-4441793354),
[configuration file location and symlinks](https://karabiner-elements.pqrs.org/docs/manual/misc/configuration-file-path/),
[Warp keyboard shortcuts](https://docs.warp.dev/getting-started/keyboard-shortcuts),
[Warp settings file](https://docs.warp.dev/terminal/settings/).
