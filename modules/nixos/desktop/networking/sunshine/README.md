# Temporary remote session recovery

When a remote-only machine is stuck at the `greetd` TUI, run the Nushell helper from an SSH session
to start one complete PAM/logind Wayland session without changing the persistent NixOS
configuration:

```bash
sudo nu ./remote-session.nu
```

The helper validates its dependencies before changing the current session. It then stops the normal
`greetd` service, starts a transient systemd-managed `greetd` configuration on `/dev/tty1`, and runs
Niri directly. It returns after greetd, Niri, and Sunshine are ready. Tailscale is not affected.

On Ryan's Intel+NVIDIA `idols-ai` host, `Virtual-1` is created by `vkms` for headless Sunshine
capture. Local `eva` is an NVIDIA-only desktop: Sunshine is enabled with NVENC, Moonlight client
state is preserved, and Intel `vkms` / `Virtual-1` is not used.

Options:

```text
-u USER       session user (defaults to SUDO_USER)
-t TTY        tty device, for example /dev/tty2
-c COMMAND    Wayland session command (defaults to niri --session)
-f, --force   replace an existing Niri session without confirmation
--check       validate prerequisites without changing service state
```

A reboot or a manual restart of `greetd.service` restores the normal TUI configuration.

## Clipboard bridge (client -> host paste)

Moonlight's `Ctrl+Alt+Shift+V` pastes by asking Sunshine to _type_ the text back as
`Ctrl+Shift+U <hex> <Enter>` key events per character. Only GTK widgets interpret that sequence, so
pasting into a browser address bar or a terminal garbles the content (a URL turns into its literal
hex form). To paste reliably, set the _real_ clipboard of the streamed session instead and then use
a normal `Ctrl+V`.

- `clipboard.nu` (host side): reads text from stdin and writes it to the clipboard of the compositor
  Sunshine is currently streaming to. The streamed session is found via the running `sunshine`
  process environment (`WAYLAND_DISPLAY`/`XDG_RUNTIME_DIR`), so this works for both the
  `greetd-sunshine` remote session and a regular desktop session.
- `send-clipboard.nu` (client side, Linux): pipes the client clipboard to the host over SSH.

Host usage (input must be piped, not typed):

```bash
printf 'https://example.com/path?q=1' | nu ./clipboard.nu
```

Client usage, from the Moonlight client (requires key-based SSH to the host and `wl-clipboard` on
the client):

```bash
wl-paste -n | ssh vitalyr@eva "nu ~/nix-vault/modules/nixos/desktop/networking/sunshine/clipboard.nu"
# or, from this repo:
nu ./send-clipboard.nu vitalyr@eva
```

`--verify` makes the host script read the clipboard back and fail on mismatch. An empty input, or a
host with no active `sunshine` process, exits with an error.
