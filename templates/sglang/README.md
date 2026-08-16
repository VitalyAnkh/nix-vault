# sglang flake

Drop-in flake for building [sglang](https://github.com/sgl-project/sglang) from a local checkout and
serving models with CUDA on NixOS + NVIDIA. Python is managed by `uv`; the sglang wheel (including
its Rust extensions) is built from the checkout itself.

## Usage

Copy `flake.nix` (and `flake.lock` for the tested input pins) into the root of an sglang checkout,
then from that checkout:

```bash
# build the sglang wheel and install it with all pinned CUDA deps into .venv-sglang
nix run .#install

# serve a model with CUDA
nix run .#serve -- --model-path Qwen/Qwen3-4B --mem-fraction-static 0.7
```

`nix run .#install` re-runs are incremental: Python deps come from the uv cache and the Rust
extensions from the cargo target cache.

## What it handles (NixOS specifics)

- PyPI CUDA wheels find the driver libs (`libcuda.so.1`) via `LD_LIBRARY_PATH` pointing at
  `/run/opengl-driver/lib`, plus a `libstdc++` for manylinux wheels.
- triton hardcodes `/sbin/ldconfig` (absent on NixOS) — bypassed via `TRITON_LIBCUDA_PATH`.
- Runtime JIT compiles (flashinfer, sglang's own kernels) use nvcc + host gcc from
  `cudaPackages_13_0`, matching the pinned torch 2.13+cu130 runtime. The pip `nvidia/cu13` tree is
  _not_ used for this: it mixes nvcc 13.3 with cudart 13.0 headers and fails.
- nixpkgs' nvcc/ld have no default include/lib search paths outside nix builds, so
  `NVCC_APPEND_FLAGS` / `CPATH` / `LIBRARY_PATH` are set for the JIT compiles.
- uv's standalone Python needs nix-ld (enabled system-wide on this machine) and gets the CA bundle
  via `SSL_CERT_FILE` (the `cuda-tile` wheel stub downloads from pypi.nvidia.com at build time).

## Resource caps

Builds are deliberately gentle so the desktop stays usable: `MAX_JOBS` / `CARGO_BUILD_JOBS` / ninja
/ make default to `-j2`, uv builds one package at a time, and the install runs `nice -n 15`. All
overridable from the environment.

## Knobs

- `SGLANG_VENV` — venv location (default `.venv-sglang`)
- `SGLANG_BUILD_RUST_EXTS=none` — skip the Rust extensions (plain HTTP serving doesn't need them;
  they're for the gRPC frontends)
- `TORCH_CUDA_ARCH_LIST` — default `8.9` (RTX 4070, sm_89); set for other GPUs
