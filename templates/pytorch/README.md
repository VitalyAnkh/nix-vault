# PyTorch source-build template (CUDA, NixOS)

Drop-in flake for building [pytorch](https://github.com/pytorch/pytorch) from a local checkout with
CUDA on NixOS + NVIDIA, and running it from a `uv`-managed venv. Build parallelism is capped so the
desktop stays responsive.

## Prerequisites

- NixOS on x86_64 with the proprietary NVIDIA driver (`/run/opengl-driver/lib`)
- flakes enabled

## Usage

Copy `flake.nix` (and `flake.lock` for the tested input pins) into the root of a pytorch checkout,
then from that checkout:

```bash
nix run .#build-torch   # build torch with CUDA (~1-3h; incremental afterwards)
nix run .#venv          # create ./.venv (uv) with the built torch inside
nix run .#smoke         # verify: import torch + matmul on the GPU
nix develop             # interactive shell: uv, python env with torch, helper scripts
```

Extra Python packages go into the venv as usual: `uv pip install --python .venv/bin/python <pkg>`.

Do **not** `import torch` from the checkout root itself: the source tree shadows the built package
(and lacks the generated `torch/version.py`). Run from any other directory, or from the venv.

## What it handles (NixOS / pytorch-main specifics)

- **Source**: fetched with `pkgs.fetchgit { fetchSubmodules = true; }` at a pinned commit. A
  `git+file:` input on the checkout breaks because nix cannot fetch submodules of local repos whose
  submodule dirs are uninitialized, and a `github:` input silently drops `?submodules=1` — both
  leave `third_party/*` empty.
- **Build backend**: pytorch main (2.15) builds via `scikit-build-core>=1.0`; nixpkgs ships 0.12.x,
  so the template overrides it to 1.0.0 (the version pytorch CI pins). The backend must be added
  with `overridePythonAttrs` — a plain `overrideAttrs` sets `build-system` without folding it into
  `nativeBuildInputs`, so the backend would not be importable during the build.
- **Build recipe**: nixpkgs' torch expression (written for the 2.12 release) is reused for its
  dependency wiring, but its version-specific patches are replaced by a minimal `postPatch` verified
  against the pinned commit, and `preBuild` only exports `MAX_JOBS` (main's scikit-build-core flow
  drives cmake/ninja itself).
- **CUPTI**: kineto on main locates CUPTI via CMake's `FindCUDAToolkit`, which wants a single
  toolkit root; nix splits CUDA across packages. `CUDAToolkit_ROOT` is pointed at
  `cudaPackages.cudatoolkit` (a symlinkJoin of all CUDA package outputs).
- **Driver libs**: found via `autoAddDriverRunpath` rpaths plus
  `LD_LIBRARY_PATH=/run/opengl-driver/lib` in the dev shell.
- **venv**: `uv venv --system-site-packages --python <nix python env>` makes the nix-built torch
  importable inside a normal uv venv.

## Resource caps

The build runs `nix build --max-jobs 1 --cores 8`; `--cores` is forwarded to
`MAX_JOBS`/`CMAKE_BUILD_PARALLEL_LEVEL`, so one derivation compiles with 8 threads at a time. Only
`sm_89` (RTX 4070, Ada) is compiled instead of every CUDA architecture — the single biggest
build-time and memory saver.

## Knobs

- `CORES=N` — compile parallelism for `nix run .#build-torch` (default 8). Each nvcc/g++ job can use
  2-4 GiB of RAM; lower it if the machine swaps.
- `cudaArchs` in `flake.nix` — GPU compute capabilities to build for (default `[ "8.9" ]`).
- `pytorch-src` in `flake.nix` — the commit to build. Change `rev`, then refresh `hash` with the
  `lib.fakeHash` trick (build once, paste the `got:` hash from the error).
- `nixpkgs` input is pinned to the rev this machine's NixOS 26.11 system uses, for maximal
  /nix/store reuse; any rev close to it should work as long as `mk-python-derivation` evaluates
  `finalAttrs.src` lazily (the nixos-unstable rev from 2026-08-14 does **not**, and breaks the
  `src`/`version` override).
