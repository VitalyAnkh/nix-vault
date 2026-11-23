# UU Remote host (uu-remote-linux)

[uu-remote-linux](https://github.com/VallierDev/uu-remote-linux) is the unofficial Linux host
(被控端) for NetEase UU Remote, so the official Windows/macOS/iOS/Android clients can control these
machines. GPL-3.0, written in Rust, built from source through the `uu-remote-linux` flake input.

Enable per host with `modules.desktop.uuRemote`:

| Host                                                                | Setting              | Result                                                   |
| ------------------------------------------------------------------- | -------------------- | -------------------------------------------------------- |
| `eva`                                                               | `enable = true`      | package, `uuremote-native` user service, uinput declared |
| `muon`                                                              | `installOnly = true` | package and uinput declared, **no** user service         |
| others importing `modules/nixos/desktop.nix` (`12kingdoms-shoukei`) | neither              | nothing but the option definitions and the overlay       |

`uinput.enable` defaults to `true` on both. Upstream recommends it for Wayland: typing a password on
the lock screen and the clipboard paste fallback for phone input methods need it, and key injection
stops depending on the keyboard layout. Set it to `false` to fall back to the xdg-desktop-portal/EIS
input path, which upstream verified on GNOME Wayland.

It grants nothing new on either host as things stand (checked 2026-11-24): `hardware.uinput.enable`
is already `true` on eva and muon because `modules.desktop.ydotoold` is on by default under
`modules.desktop.codexDesktop.computerUse`, and the users are in the `uinput` group. eva's running
system also already tags `/dev/uinput` with `uaccess` from the Sunshine and Steam Input rules, so
the package's own rule is redundant there; on muon it is the only `uaccess` rule, but group
membership already grants wider access than `uaccess` does (every group member, not just the active
seat user). The declaration is kept explicit so the capability survives ydotoold being turned off
rather than depending on an unrelated module's side effect.

Keep the underlying privilege in mind when changing any of this: `/dev/uinput` lets its holder
inject input anywhere on the seat, lock and greeter screens included.

The host needs **no inbound ports**: it dials the vendor's signalling and TURN relays outbound, so
the default-deny firewall is left alone.

## First run

Enabling the service installs the unit but puts nothing online. Each user logs in once, from a
graphical session:

```sh
uuremote-server login                               # scan the QR code with the UU app
systemctl --user status uuremote-native.service
uuremote-server doctor                              # also reports duplicate host instances
```

## Device identity — do not clone it

`~/.config/uuremote/config.json` (mode 0600) holds the account token **and this machine's device
identity** (`device_id`, `client_id`, `system_id`). Two hosts carrying the same identity keep
kicking each other out of the room: the log shows `Cloud room leave without peer identifier` every
few seconds and clients disconnect immediately after connecting.

So never copy that directory between machines, and never clone a host from a snapshot or data disk
that carries it. If it happened anyway: stop the service, delete `device_id`, `client_id`,
`system_id`, `token`, `csrf` and `user_id` from the file, then run `uuremote-server login` again to
register as a new device.

The directory is persisted per host in `hosts/eva/preservation.nix` (muon reuses that user list), so
it survives the tmpfs root. Nothing in this repository writes to it.

## Using it on muon

`installOnly` deliberately registers no user unit. A user who wants the host there links the unit
template that ships with the package and starts it themselves:

```sh
systemctl --user link /run/current-system/sw/lib/systemd/user/uuremote-native.service
systemctl --user daemon-reload
uuremote-server login
systemctl --user enable --now uuremote-native.service
```

`graphical-session.target` is not running when nobody is logged in; for a host that should be
reachable after a plain boot, change the unit's `WantedBy` to `default.target` and run
`loginctl enable-linger $USER`.

## Settings

Per-host tuning goes into `~/.config/uuremote/env.conf` (one `KEY=VALUE` per line, only `UU_*`
names, read at service start) rather than into the Nix module, so it survives unit changes.
`services.uu-remote-linux.settings` sets `Environment=` on the unit and overrides that file. Account
credentials are never accepted in `env.conf`.

Two knobs worth knowing:

- `UU_PORT_MAPPING=0` disables the official "port mapping" feature, which otherwise lets the
  controlling side forward its local ports to anything this host can reach, `127.0.0.1:22` included.
- Do **not** set `UU_BASE_URL` on the unit. It overrides the value `uuremote-server login` wrote
  into `config.json`, and a mismatch sends credentials to a different server.

Encoder and codec are stored in `~/.config/uuremote/host_settings.json` and changed with
`uuremote-server set-encoder` / `set-codec`; with an NVIDIA GPU present, `auto` prefers NVENC and
falls back to CPU. The package is built with `withInprocAv = false` (upstream's default), so
encoding goes through the bundled FFmpeg CLI; in-process NVENC/VAAPI needs
`package = pkgs.uu-remote-linux.override { withInprocAv = true; }`.

## Desktop support

The package is built with the `wayland`, `portal` and `native-viewer` features. Upstream rates X11
as fully verified, and GNOME/KDE Wayland through xdg-desktop-portal as experimental: on GNOME it has
verified capture, keyboard/mouse and lock-screen cold connect with auto-unlock, while resolution
changes are not supported on the portal backend and the clipboard only syncs while the client's
window is focused. eva runs GNOME on Wayland, so expect the portal path.
