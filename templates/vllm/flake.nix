{
  description = "Build vLLM (this checkout) from source with CUDA and run it on the local GPU (NixOS, uv-managed .venv, resource-capped build)";

  # Why this design (read before hacking on it):
  # - vLLM's CUDA kernels are compiled from this checkout by `uv pip install -e .`
  #   (the workflow in AGENTS.md). A sandboxed `nix build` cannot do this: uv/pip
  #   need network access and cargo needs crates.io.
  # - PyPI manylinux wheels (torch, triton, ...) only run on NixOS via nix-ld,
  #   which is enabled system-wide here; we still set NIX_LD* explicitly so the
  #   shell works even if the global variables are missing.
  # - the pip torch stack is pinned to cu130 (see the comment on `cuda` below),
  #   and nvcc comes from cudaPackages_13_0 so the toolkit and the torch
  #   runtime stay on the same CUDA version.
  # - Build parallelism is deliberately tiny (MAX_JOBS=4, NVCC_THREADS=1) so the
  #   desktop stays usable; each nvcc job can eat 4-6 GiB of RAM.

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true; # NVIDIA CUDA toolkit EULA
      };

      # The whole pip torch stack is pinned to cu130: torch ships cu132 wheels
      # (which uv --torch-backend=auto would pick), but torchaudio has no cu132
      # build at all and hard-fails on import when its CUDA version differs
      # from torch's. cu130 builds exist for torch/torchaudio/torchvision/
      # torchcodec alike, and nvcc 13.0 matches that runtime.
      cuda = pkgs.cudaPackages_13_0;
      torchBackend = "cu130";
      python = pkgs.python312; # vllm requires >=3.10,<3.15

      # RTX 4070 = Ada Lovelace, sm_89. Building a single arch cuts the
      # kernel compile time roughly by the number of default archs.
      torchCudaArchList = "8.9";

      # Resource caps. Bump maxJobs only if you are fine with more RAM/CPU use.
      maxJobs = "4";

      buildTools = [
        pkgs.uv
        python
        pkgs.git # setuptools-scm derives the version from git
        pkgs.stdenv.cc # host C/C++ compiler for cmake/nvcc
        pkgs.cmake
        pkgs.ninja
        pkgs.cargo
        pkgs.rustc
        pkgs.gnumake # cargo: vendored openssl build
        pkgs.perl # cargo: vendored openssl build
        pkgs.ccache # incremental rebuilds across setup re-runs
        cuda.cudatoolkit # nvcc + headers + cudart
      ];

      # libs that PyPI manylinux binaries need via nix-ld
      wheelLibs = [
        pkgs.stdenv.cc.cc.lib # libstdc++, libgomp
        pkgs.zlib
      ];

      nixLdLibPath = lib.makeLibraryPath wheelLibs + ":/run/current-system/sw/share/nix-ld/lib";

      # NixOS exposes the proprietary driver libs here; torch dlopens libcuda.
      driverLibPath = "/run/opengl-driver/lib";

      buildEnv = {
        CUDA_HOME = "${cuda.cudatoolkit}";
        TORCH_CUDA_ARCH_LIST = torchCudaArchList;

        MAX_JOBS = maxJobs; # vllm setup.py: number of parallel compile jobs
        NVCC_THREADS = "1"; # vllm setup.py: threads per nvcc job
        CMAKE_BUILD_PARALLEL_LEVEL = maxJobs;
        NINJAFLAGS = "-j${maxJobs}";
        CARGO_BUILD_JOBS = maxJobs;

        # sccache from the user profile is auto-detected by setup.py but broken
        # in this environment ("cannot find binary path"); disable it
        VLLM_DISABLE_SCCACHE = "1";

        NIX_LD = "/run/current-system/sw/share/nix-ld/lib/ld.so";
        NIX_LD_LIBRARY_PATH = nixLdLibPath;

        # runtime: libcuda from the NixOS driver + libstdc++/zlib for dlopen'ed
        # wheel libs (nix-ld only fixes the ELF interpreter of executables;
        # .so dependencies are resolved through LD_LIBRARY_PATH)
        LD_LIBRARY_PATH = driverLibPath + ":" + lib.makeLibraryPath wheelLibs;
        # triton's libcuda_dirs() hardcodes /sbin/ldconfig, which NixOS lacks
        TRITON_LIBCUDA_PATH = driverLibPath;
        # nixpkgs' nvcc relies on stdenv setup hooks for the cudart header/lib
        # search paths; we are not in a stdenv build, so provide them manually
        CPLUS_INCLUDE_PATH = "${cuda.cudatoolkit}/include";
        # link-time: libcuda stub + cudart & friends
        LIBRARY_PATH = "${cuda.cudatoolkit}/lib/stubs:${cuda.cudatoolkit}/lib";

        # Slow network? Uncomment:
        # UV_DEFAULT_INDEX = "https://pypi.tuna.tsinghua.edu.cn/simple";
        # HF_ENDPOINT = "https://hf-mirror.com";
      };

      # Creates .venv/ in the repo root and builds+installs vllm into it.
      setup = pkgs.writeShellApplication {
        name = "setup";
        runtimeInputs = buildTools;
        runtimeEnv = buildEnv;
        text = ''
          set -euo pipefail
          root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
          cd "$root"

          if [ ! -d .venv ]; then
            uv venv --python "${python}/bin/python3.12" .venv
          fi

          # Build deps. requirements/build/cuda.txt pins torch==*+cpu (meant for
          # GPU-less build machines), which cannot link CUDA extensions, so
          # install the CUDA build of torch explicitly instead.
          uv pip install --python .venv/bin/python --torch-backend=${torchBackend} \
            "torch==2.13.0" \
            "setuptools>=77.0.3,<81.0.0" "setuptools-scm>=8" "setuptools-rust>=1.9.0" \
            "packaging>=24.2" wheel jinja2 regex

          # Full source build of the CUDA kernels (~1h at MAX_JOBS=${maxJobs}).
          # For Python-only iteration you can use VLLM_USE_PRECOMPILED=1 instead
          # (see AGENTS.md), which skips kernel compilation entirely.
          uv pip install --python .venv/bin/python --torch-backend=${torchBackend} \
            --no-build-isolation -e .

          .venv/bin/python -c "import vllm; print('vllm', vllm.__version__, 'OK')"
          echo "done. try: nix run .#vllm -- serve <model>"
        '';
      };

      # Thin launcher around the .venv built by `setup`.
      vllm = pkgs.writeShellApplication {
        name = "vllm";
        runtimeInputs = [ pkgs.git ];
        runtimeEnv = {
          NIX_LD = buildEnv.NIX_LD;
          NIX_LD_LIBRARY_PATH = nixLdLibPath;
          LD_LIBRARY_PATH = buildEnv.LD_LIBRARY_PATH;
          TRITON_LIBCUDA_PATH = buildEnv.TRITON_LIBCUDA_PATH;
          # HF_ENDPOINT = "https://hf-mirror.com";
        };
        text = ''
          root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
          if [ ! -x "$root/.venv/bin/vllm" ]; then
            echo "error: vllm is not installed yet; run: nix run .#setup" >&2
            exit 1
          fi
          exec "$root/.venv/bin/vllm" "$@"
        '';
      };
    in
    {
      packages.${system} = {
        inherit setup vllm;
        default = setup;
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = buildTools ++ [ setup ];
        env = buildEnv;
        shellHook = ''
          echo "vLLM CUDA dev shell (TORCH_CUDA_ARCH_LIST=${torchCudaArchList}, MAX_JOBS=${maxJobs})"
          echo "  build + install:  setup"
          echo "  run:              .venv/bin/vllm serve <model>"
        '';
      };
    };
}
