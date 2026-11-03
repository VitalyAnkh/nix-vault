# Editor tooling packages (heavy dependencies)

This directory holds [`packages.nix`](./packages.nix) for language servers, formatters, compilers,
and other editor-adjacent tools that pull in a large closure.

It also keeps the local [`emacs`](./emacs/) Home Manager module because that module wires the custom
Emacs PGTK package and Doom Emacs activation.

Editor programs, keymaps, `$EDITOR` defaults, and usage docs live under
[`../../core/editors/`](../../core/editors/README.md) for Helix and the minimal Neovim backup.

[`default.nix`](./default.nix) imports [`ipython/`](./ipython/), `./packages.nix` and `./emacs` so
`home/base/tui` can keep pulling in heavy tooling and the local Emacs module without mixing them
into `core/editors`. It keeps IPython's history on, unlike upstream: only the startup helpers from
`ipython/` are installed, and eva still persists `~/.ipython`.
