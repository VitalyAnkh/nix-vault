# Unreal Wrapper

This package provides a Linux-only wrapper around a locally prepared Unreal Engine 5 checkout. It is
intentionally **not** a full Unreal Engine distribution and it does **not** copy your engine source
tree into `/nix/store`.

## What this package is for

- Launching an existing Unreal Engine checkout from NixOS or Home Manager
- Providing a reproducible wrapper with FHS runtime dependencies
- Making Unreal usable as a flake-exposed package from `nix-vault`

## What this package is not

- It does not download Unreal Engine for you
- It does not build Unreal Engine for you
- It does not vendor your local checkout into the Nix store
- It is not a NixOS module; it is a package that you can install or reference directly

## Requirements

The wrapper expects a working Unreal checkout that already contains a built editor binary:

```text
$UE_SRC/Engine/Binaries/Linux/UnrealEditor
```

Typical setup:

- clone Unreal Engine locally
- run Epic's setup/build flow
- point `UE_SRC` at that checkout

## Using this flake as an external input

You can consume the package from another flake directly:

```nix
inputs.nix-vault.url = "github:VitalyAnkh/nix-vault";

environment.systemPackages = [
  inputs.nix-vault.packages.${pkgs.system}.unreal
];
```

The same pattern works for Home Manager:

```nix
home.packages = [
  inputs.nix-vault.packages.${pkgs.system}.unreal
];
```

## Configuring the Unreal source path

The wrapper reads the Unreal checkout path from `UE_SRC` at runtime. This environment variable is
required; the wrapper does not bake a machine-specific checkout path into the derivation.

For NixOS:

```nix
environment.sessionVariables.UE_SRC = "/home/you/UnrealEngine";
```

For Home Manager:

```nix
home.sessionVariables.UE_SRC = "/home/you/UnrealEngine";
```

If `UE_SRC` is not set, the wrapper exits with a clear error and does not start Unreal.

## Entry points

The package exposes the Unreal editor wrapper as its main program:

- `ue5editor`
- `ue5`
- `UE5`
- `unreal-engine-5`

You can also invoke it directly through the flake:

```bash
nix build .#unreal
nix run .#unreal
```

## Notes

- The wrapper adds a local FHS environment and runtime libraries needed by Unreal on Linux.
- Runtime behavior can still be influenced through Unreal-specific environment variables such as
  `UE_SDL_VIDEODRIVER`, `UE_MALLOC_MODE`, `UE_VULKAN_PRESENT_MODE`, and `UE_GPU_SAFE_MODE`.
- If you want to launch Unreal from this package, set `UE_SRC` in your user session configuration
  rather than baking a checkout path into the derivation.
