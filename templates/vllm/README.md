# vLLM source-build template (CUDA, NixOS)

Builds vLLM from a local source checkout with CUDA kernel compilation, using a uv-managed `.venv`,
and runs it on the local NVIDIA GPU. Build parallelism is capped so the desktop stays responsive.

## Prerequisites

- NixOS on x86_64 with the proprietary NVIDIA driver (`/run/opengl-driver/lib`)
- `programs.nix-ld.enable = true` (PyPI manylinux wheels need it)
- flakes enabled

## Usage

Copy `flake.nix` (and optionally `flake.lock`) into the root of a vLLM checkout, then:

```bash
# One-off upstream fix: on affected commits (vllm main ~2026-08), sm_80/86/89
# builds fail because fused_gdn_decode_post_conv_mtp is declared under the
# wrong preprocessor guard. Apply if it applies cleanly, skip if already fixed:
git apply --check /path/to/patches/fused-gdn-decode-decl-guard.patch && \
  git apply /path/to/patches/fused-gdn-decode-decl-guard.patch

nix run .#setup    # create .venv, install CUDA torch stack, compile+install vllm (~1h)
nix run .#vllm -- serve Qwen/Qwen3-0.6B
nix develop        # interactive shell: uv, nvcc, ccache, ...
```

## Knobs (top of flake.nix)

- `maxJobs` — compile parallelism (default 4). Each nvcc job can use 4-6 GiB of RAM; keep
  `maxJobs * 6 GiB` below available memory.
- `torchCudaArchList` — target GPU arch (default `"8.9"`, RTX 40xx). Single arch keeps compile time
  down.
- `torchBackend` — pip torch backend (default `cu130`). Must stay in sync with the `cudaPackages_*`
  choice; torchaudio has no cu132 build and hard-fails on a CUDA version mismatch, so the whole
  stack is pinned to cu130.

## Notes

- Kernel compilation happens once; later rebuilds reuse ccache.
- For Python-only iteration set `VLLM_USE_PRECOMPILED=1` to skip kernel builds.
- If the desktop holds GPU memory, serve with `--gpu-memory-utilization 0.5` or similar.
- Slow network: uncomment the mirror variables in `flake.nix` (`UV_DEFAULT_INDEX`, `HF_ENDPOINT`).
