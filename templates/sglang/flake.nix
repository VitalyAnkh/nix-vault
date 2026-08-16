{
  description = "Build sglang from this repo and serve models with CUDA (NixOS + NVIDIA; Python env managed by uv; resource-limited build)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      # allowUnfree is scoped to this flake only (CUDA toolkit is unfree).
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      pythonVersion = "3.12";
      # The CUDA compute capability of the local GPU (RTX 4070 = sm_89).
      # Used for any JIT/source-built torch extensions; override per GPU.
      defaultCudaArch = "8.9";

      # CUDA toolkit for FlashInfer's runtime JIT compiles. Version matches
      # torch 2.13.0+cu130 exactly; do NOT use the pip nvidia/cu13 tree —
      # it mixes nvcc 13.3 with cudart 13.0 headers and fails to compile.
      # backendStdenv.cc is the host gcc blessed for this CUDA version
      # (used by nvcc and by triton's runtime C shim).
      cudaToolkit = pkgs.cudaPackages_13_0.cudatoolkit;
      cudaHostCc = pkgs.cudaPackages_13_0.backendStdenv.cc;

      # Tools needed to build the sglang wheel (incl. its Rust extensions).
      buildTools = with pkgs; [
        uv
        git # setuptools-scm derives the version from git
        cargo
        rustc
        protobuf # protoc for the gRPC Rust extension
        pkg-config
        openssl
        cmake
        stdenv.cc # linker + C compiler for Rust -sys crates
        gnumake
        cacert
      ];

      # Keep the build gentle: few parallel jobs, low scheduling priority.
      # Everything is overridable from the environment.
      resourceLimits = ''
        export MAX_JOBS="''${MAX_JOBS:-2}"
        export CARGO_BUILD_JOBS="''${CARGO_BUILD_JOBS:-2}"
        export CMAKE_BUILD_PARALLEL_LEVEL="''${CMAKE_BUILD_PARALLEL_LEVEL:-2}"
        export MAKEFLAGS="''${MAKEFLAGS:--j2}"
        export NINJAFLAGS="''${NINJAFLAGS:--j2}"
        export UV_CONCURRENT_BUILDS="''${UV_CONCURRENT_BUILDS:-1}"
        export UV_CONCURRENT_INSTALLS="''${UV_CONCURRENT_INSTALLS:-2}"
        export UV_CONCURRENT_DOWNLOADS="''${UV_CONCURRENT_DOWNLOADS:-4}"
      '';

      # NixOS: PyPI CUDA wheels need the NVIDIA driver libs (libcuda.so.1 lives
      # in /run/opengl-driver/lib) plus a C++ runtime for manylinux wheels.
      cudaEnv = ''
        export LD_LIBRARY_PATH="/run/opengl-driver/lib:${pkgs.stdenv.cc.cc.lib}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        export TORCH_CUDA_ARCH_LIST="''${TORCH_CUDA_ARCH_LIST:-${defaultCudaArch}}"
        # Triton locates libcuda via /sbin/ldconfig, which does not exist on
        # NixOS; point it at the driver libs directly.
        export TRITON_LIBCUDA_PATH="''${TRITON_LIBCUDA_PATH:-/run/opengl-driver/lib}"
        export CUDA_HOME="''${CUDA_HOME:-${cudaToolkit}}"
        # The JIT link step needs libcuda (driver lib) and libcudart (toolkit
        # lib); nix's ld has no default search path for either.
        export LIBRARY_PATH="/run/opengl-driver/lib:${cudaToolkit}/lib''${LIBRARY_PATH:+:$LIBRARY_PATH}"
        # nixpkgs' nvcc does not auto-add its own include dir (that normally
        # happens via nix build setup hooks), so sglang's JIT .cu compiles
        # cannot find cuda_runtime.h without these.
        export NVCC_APPEND_FLAGS="-I${cudaToolkit}/include''${NVCC_APPEND_FLAGS:+ $NVCC_APPEND_FLAGS}"
        export CPATH="${cudaToolkit}/include''${CPATH:+:$CPATH}"
      '';

      install = pkgs.writeShellApplication {
        name = "sglang-install";
        runtimeInputs = buildTools;
        text = ''
          set -euo pipefail

          if [ ! -f python/pyproject.toml ] || [ ! -d rust ]; then
            echo "error: run this from the root of the sglang repository" >&2
            exit 1
          fi

          VENV="''${SGLANG_VENV:-.venv-sglang}"
          ${resourceLimits}

          echo "[1/3] creating Python ${pythonVersion} venv at $VENV (via uv)"
          if [ ! -d "$VENV" ]; then
            uv venv --python ${pythonVersion} "$VENV"
          fi

          # Build the sglang wheel from ./python and install it with all pinned
          # CUDA dependencies (torch cu13, sglang-kernel, flashinfer, ...).
          # Rust extensions are built by default; skip the cargo build with:
          #   SGLANG_BUILD_RUST_EXTS=none nix run .#install
          # The user's global uv config sets a rolling `exclude-newer = "2 days"`
          # cutoff, but this repo pins freshly-published packages (e.g.
          # sgl-deep-gemm 0.1.5.post3). Override the cutoff for this install
          # only (env var beats config file; the global config is untouched).
          export UV_EXCLUDE_NEWER="''${UV_EXCLUDE_NEWER:-2100-01-01T00:00:00Z}"

          # uv's standalone Python cannot find the NixOS CA store by itself;
          # the cuda-tile wheel stub downloads from pypi.nvidia.com at build
          # time and fails SSL verification without this.
          export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
          export NIX_SSL_CERT_FILE="$SSL_CERT_FILE"

          echo "[2/3] building sglang from ./python and installing into $VENV"
          echo "      (rust extensions: ''${SGLANG_BUILD_RUST_EXTS:-all}, jobs: $MAX_JOBS)"
          nice -n 15 uv pip install --python "$VENV/bin/python" \
            --reinstall-package sglang ./python

          echo "[3/3] verifying CUDA availability"
          ${cudaEnv}
          "$VENV/bin/python" - <<'PYEOF'
          import importlib.metadata

          import torch

          assert torch.cuda.is_available(), "torch reports CUDA as unavailable"
          import sglang  # noqa: F401
          import sgl_kernel  # noqa: F401  (PyPI: sglang-kernel)

          print("torch        :", torch.__version__, "(cuda", torch.version.cuda + ")")
          print("gpu          :", torch.cuda.get_device_name(0),
                "capability", torch.cuda.get_device_capability(0))
          print("sglang       :", importlib.metadata.version("sglang"))
          print("sgl_kernel   : OK")
          PYEOF

          echo
          echo "done. Serve a model with:"
          echo "  nix run .#serve -- --model-path Qwen/Qwen3-4B --mem-fraction-static 0.7"
        '';
      };

      serve = pkgs.writeShellApplication {
        name = "sglang-serve";
        # nvcc (+ its blessed host gcc) for FlashInfer runtime JIT compiles;
        # triton's C shim also needs a cc.
        runtimeInputs = [
          cudaToolkit
          cudaHostCc
        ];
        text = ''
          set -euo pipefail

          VENV="''${SGLANG_VENV:-.venv-sglang}"
          if [ ! -x "$VENV/bin/sglang" ]; then
            echo "error: $VENV not found; run 'nix run .#install' first" >&2
            exit 1
          fi
          # Absolute path: JIT subprocesses run with a different cwd.
          VENV="$(cd "$VENV" && pwd)"

          ${cudaEnv}
          # Bound the parallelism of runtime JIT compiles as well.
          export MAX_JOBS="''${MAX_JOBS:-2}"

          exec "$VENV/bin/sglang" serve "$@"
        '';
      };
    in
    {
      packages.${system} = {
        inherit install serve;
        default = install;
      };

      apps.${system} = {
        default = {
          type = "app";
          program = "${install}/bin/sglang-install";
        };
        install = {
          type = "app";
          program = "${install}/bin/sglang-install";
        };
        serve = {
          type = "app";
          program = "${serve}/bin/sglang-serve";
        };
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = buildTools ++ [
          cudaToolkit
          cudaHostCc
        ];
        shellHook = ''
          ${resourceLimits}
          ${cudaEnv}
          export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
          export NIX_SSL_CERT_FILE="$SSL_CERT_FILE"
          echo "sglang build shell (jobs limited: MAX_JOBS=$MAX_JOBS, CARGO_BUILD_JOBS=$CARGO_BUILD_JOBS)"
          echo "  nix run .#install                      # build sglang into .venv-sglang via uv"
          echo "  nix run .#serve -- --model-path ...    # serve a model with CUDA"
        '';
      };
    };
}
