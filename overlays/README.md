# Overlays

Overlays for both NixOS and Nix-Darwin.

If you don't know much about overlays, it is recommended to learn the function and usage of overlays
through [Overlays - NixOS & Flakes Book](https://nixos-and-flakes.thiscute.world/nixpkgs/overlays).

## Current Structure

```
overlays/
├── README.md
├── default.nix            # Entrypoint for all overlays
├── computer-use-linux.nix # computer-use-linux from pkgs/computer-use-linux
├── cua-driver.nix         # cua-driver from pkgs/cua-driver
└── smartctl-exporter/     # smartctl_exporter pinned to the #329 fix
    └── default.nix
```

## Components

### 1. `default.nix`

The entrypoint imports every overlay file in this directory and applies it to the given arguments.

### 2. Package overlays

- `computer-use-linux.nix`: exposes the local `pkgs/computer-use-linux` package (this fork builds it
  under `pkgs/` instead of taking `nur-ryan4yin`'s).
- `cua-driver.nix`: exposes the local `pkgs/cua-driver` package (used by the computer-use VMs).
- `smartctl-exporter/`: pins `prometheus-smartctl-exporter` to the upstream commit carrying PR
  [#329](https://github.com/prometheus-community/smartctl_exporter/pull/329) until nixpkgs provides
  a version containing the fix; see `overlays/smartctl-exporter/default.nix`.
