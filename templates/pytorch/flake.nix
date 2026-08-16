{
  description = "Build PyTorch from this checkout (main / 2.15.0a0) with CUDA support, and run it in a uv-managed Python environment";

  # ==========================================================================
  # Drop-in flake: copy this file (and flake.lock for the tested pins) into the
  # root of a pytorch checkout. See templates/pytorch/README.md in nix-vault.
  #
  # Usage (run from the pytorch repository root):
  #
  #   nix run .#build-torch     # build PyTorch with limited resources.
  #                             # Default: --max-jobs 1 --cores 8.
  #                             # Tune with: CORES=6 nix run .#build-torch
  #
  #   nix run .#venv            # create ./.venv via uv, with the freshly built
  #                             # CUDA torch available inside it
  #
  #   nix run .#smoke           # smoke test: import torch + CUDA matmul on GPU
  #
  #   nix develop               # shell with uv, the torch python env, and the
  #                             # helper scripts above on PATH
  #
  # Resource control: `nix build` parallelism is governed by --cores, which the
  # build maps onto MAX_JOBS / CMAKE_BUILD_PARALLEL_LEVEL (see preBuild), and
  # --max-jobs 1 keeps a single derivation compiling at a time. Additionally
  # only sm_89 (RTX 4070, Ada) is compiled instead of every CUDA architecture,
  # which is by far the biggest build-time/memory saver.
  # ==========================================================================

  inputs = {
    # Pinned to the same nixpkgs rev as this machine's NixOS 26.11 system:
    # maximal /nix/store overlap (most build deps already present locally),
    # and its python buildPythonPackage evaluates `finalAttrs.src` lazily
    # enough to allow the src/version overrides below.
    nixpkgs.url = "github:NixOS/nixpkgs/2b4b728c598fff722292310a5be945e390356061";
  };

  outputs =
    {
      self,
      nixpkgs,
    }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        # CUDA toolkit, cuDNN, NCCL etc. carry unfree (redistributable) licenses.
        config.allowUnfree = true;
      };

      inherit (pkgs) lib;

      # --------------------------------------------------------------------
      # Source tree to build: the exact commit this checkout is on
      # (8aac66fb022 = local HEAD, pushed on pytorch main), cloned from GitHub
      # with all submodules recursively (they are required for the build and
      # are not initialized in this local checkout).
      #
      # Why not the local directory or a github: flake input?
      #   - local git+file: repo: nix's submodule handling breaks when the
      #     submodule checkouts are not initialized (ours are all empty);
      #   - github: input with ?submodules=1: the parameter is silently
      #     dropped and the fetched tree has empty third_party/* dirs.
      #   pkgs.fetchgit with fetchSubmodules runs a real recursive
      #   `git submodule update --init`, which works.
      #
      # To build a different commit: change `rev`, and refresh `hash` via the
      # lib.fakeHash trick (build, then paste the "got:" hash from the error).
      # --------------------------------------------------------------------
      pytorch-src = pkgs.fetchgit {
        url = "https://github.com/pytorch/pytorch";
        rev = "8aac66fb022576e2d13144ab636372f686f23cfa";
        fetchSubmodules = true;
        hash = "sha256-sqjhVPnau2FmzU/2vbYsy2kiziNkiIBOF9JUc59HQes=";
      };

      # RTX 4070 (Ada Lovelace) => sm_89. Single arch keeps the CUDA compile
      # time and peak RAM low.
      cudaArchs = [ "8.9" ];

      pytorchVersion = "2.15.0a0"; # version.txt of this checkout

      # ----------------------------------------------------------------------
      # scikit-build-core 1.0.0
      #
      # PyTorch main builds via the scikit-build-core PEP 517 backend and
      # requires >= 1.0 (see pyproject.toml [build-system]); nixpkgs still
      # ships 0.12.x. 1.0.0 is the exact version PyTorch CI pins in
      # .ci/docker/requirements-ci.txt. Pure-python package, cheap to build.
      # ----------------------------------------------------------------------
      scikit-build-core = pkgs.python3Packages.scikit-build-core.overridePythonAttrs (old: rec {
        version = "1.0.0";
        src = pkgs.fetchFromGitHub {
          owner = "scikit-build";
          repo = "scikit-build-core";
          tag = "v${version}";
          hash = "sha256-K+6drFjDylyq+nzKYoHpu+4fuPuFJ+we2lXFGFH0o9Q=";
        };
        # The setuptools-scm-10 compat patch nixpkgs carries for 0.12.x is
        # already merged upstream in 1.0.0.
        patches = [ ];
        doCheck = false;
      });

      # ----------------------------------------------------------------------
      # torch with CUDA, built from this checkout
      #
      # Reuses nixpkgs' torch expression (dependency wiring, env vars,
      # multi-output split, rpath fixups) but overrides:
      #   - src/version to this checkout
      #   - patches/postPatch, which target the 2.12.0 release and partly do
      #     not apply to main; the still-relevant fixes are re-done below
      #   - preBuild: main no longer uses the legacy setup.py flow
      # ----------------------------------------------------------------------
      torch-cuda =
        (pkgs.python3Packages.torch.override {
          cudaSupport = true;
          gpuTargets = cudaArchs;
          withNvshmem = false; # single-GPU machine; skips the nvshmem dependency
        }).overridePythonAttrs
          (old: {
            version = pytorchVersion;
            src = pytorch-src;

            patches = [ ];

            postPatch = ''
              # Tools torch shells out to at runtime -> absolute nix store paths.
              substituteInPlace torch/_inductor/codecache.py \
                --replace-fail '"openssl"' '"${lib.getExe pkgs.openssl}"'
              substituteInPlace torch/csrc/profiler/unwind/unwind.cpp \
                --replace-fail 'addr2line_binary_ = "addr2line"' \
                  'addr2line_binary_ = "${lib.getExe' pkgs.binutils "addr2line"}"'
              substituteInPlace torch/_inductor/config.py \
                --replace-fail '"clang++" if sys.platform == "darwin" else "g++"' \
                  '"${lib.getExe' pkgs.stdenv.cc "${pkgs.stdenv.cc.targetPrefix}c++"}"'

              # CUDA toolkit discovery against nix's split cudaPackages layout:
              # tolerate "conflicting" toolkit versions and don't pin
              # CUDAToolkit_ROOT to a single component.
              substituteInPlace cmake/public/cuda.cmake \
                --replace-fail 'message(FATAL_ERROR "Found two conflicting CUDA' \
                  'message(WARNING "Found two conflicting CUDA' \
                --replace-fail 'set(CUDAToolkit_ROOT' '# nix: set(CUDAToolkit_ROOT'

              # Use CMake's own FindCUDAToolkit module (delete the vendored,
              # patched copy) and drop its now-dangling install() rule.
              rm cmake/Modules/FindCUDAToolkit.cmake
              sed -i '/^  install($/ { :loop; N; /COMPONENT dev)/! b loop; /FindCUDAToolkit\.cmake/d }' CMakeLists.txt

              # Locate nvtx3 via its header (same fix as nixpkgs' nvtx3 patch).
              substituteInPlace cmake/Dependencies.cmake \
                --replace-fail \
                  'find_path(nvtx3_dir NAMES nvtx3 PATHS ''${CUDA_INCLUDE_DIRS})' \
                  'find_path(nvtx3_dir NAMES nvtx3/nvtx3.hpp PATHS ''${CUDA_INCLUDE_DIRS})' \
                --replace-fail \
                  'find_path(nvtx3_dir NAMES nvtx3 PATHS "''${PROJECT_SOURCE_DIR}/third_party/NVTX/c/include" NO_DEFAULT_PATH)' \
                  'find_path(nvtx3_dir NAMES nvtx3/nvtx3.hpp PATHS "''${PROJECT_SOURCE_DIR}/third_party/NVTX/c/include" NO_DEFAULT_PATH)'

              # Submodule files below live under third_party/; guard in case
              # their layout moves on main.
              if [ -f third_party/gloo/cmake/Cuda.cmake ]; then
                substituteInPlace third_party/gloo/cmake/Cuda.cmake \
                  --replace-warn 'find_package(CUDAToolkit 7.0' 'find_package(CUDAToolkit'
              fi
              if [ -f third_party/NNPACK/CMakeLists.txt ]; then
                # Let NNPACK's PeachPy codegen see six from the build env, and
                # point its six download rule at the nix-provided source.
                substituteInPlace third_party/NNPACK/CMakeLists.txt \
                  --replace-warn 'PYTHONPATH=' 'PYTHONPATH=$ENV{PYTHONPATH}:'
                sed -i '2s;^;set(PYTHON_SIX_SOURCE_DIR ${pkgs.python3Packages.six.src})\n;' third_party/NNPACK/CMakeLists.txt
              fi
            '';

            # PEP 517 build backend of pytorch main (nixpkgs' list predates the
            # scikit-build-core migration). NOTE: must go through
            # overridePythonAttrs -- a plain overrideAttrs would set the attr
            # but never fold it into nativeBuildInputs, and the backend would
            # not be importable during pypaBuildPhase.
            build-system = old.build-system ++ [ scikit-build-core ];

            # The kineto version on pytorch main detects CUPTI via CMake's
            # FindCUDAToolkit (CUDA::cupti target), which needs a single
            # toolkit root -- but nix splits the CUDA toolkit across packages.
            # Point it at cudaPackages.cudatoolkit, a symlinkJoin of all CUDA
            # 12.9 package outputs, so cupti & co. are found. (The
            # CUDAToolkit_ROOT override in cmake/public/cuda.cmake is disabled
            # in postPatch, so this env var survives.)
            preConfigure = old.preConfigure + ''
              export CUDAToolkit_ROOT=${pkgs.cudaPackages.cudatoolkit}
            '';

            # main builds via scikit-build-core (the backend drives
            # cmake/ninja); nixpkgs' preBuild drives the legacy setup.py flow.
            preBuild = ''
              # PyTorch's umbrella parallelism knob; the scikit-build-core env
              # table aliases it to CMAKE_BUILD_PARALLEL_LEVEL. Tied to nix's
              # --cores value so `nix build --cores N` controls everything.
              export MAX_JOBS=''${NIX_BUILD_CORES:-8}
            '';
          });

      # Python environment carrying the freshly built torch.
      pythonEnv = pkgs.python3.withPackages (ps: [
        torch-cuda
        ps.numpy
      ]);

      # --------------------------------------------------------------------
      # Helper scripts
      # --------------------------------------------------------------------

      # Builds torch-cuda with deliberately few parallel jobs. Honors CORES.
      buildScript = pkgs.writeShellScriptBin "pytorch-build" ''
        set -euo pipefail
        if [ ! -f flake.nix ]; then
          echo "error: run this from the pytorch repository root (where flake.nix lives)" >&2
          exit 1
        fi
        cores="''${CORES:-8}"
        echo ">> nix build .#torch-cuda --max-jobs 1 --cores $cores"
        echo ">> (set CORES=N to change; build takes roughly 1-3h at 8 cores)"
        exec nix build ".#torch-cuda" \
          --max-jobs 1 \
          --cores "$cores" \
          --print-build-logs \
          "$@"
      '';

      # Creates ./.venv with uv, based on the nix python env that already
      # contains the built torch. --system-site-packages makes torch (and
      # numpy) visible inside the venv; extra packages can be added with
      # `uv pip install` afterwards.
      venvScript = pkgs.writeShellScriptBin "pytorch-venv" ''
        set -euo pipefail
        venv="''${1:-.venv}"
        if [ ! -e "$venv/bin/python" ]; then
          ${pkgs.uv}/bin/uv venv --system-site-packages \
            --python ${pythonEnv}/bin/python3 "$venv"
        fi
        echo "venv ready at: $venv"
        echo "  activate:           source $venv/bin/activate"
        echo "  add packages:       uv pip install --python $venv/bin/python <pkg>"
        echo "  verify cuda:        $venv/bin/python -c 'import torch; print(torch.cuda.is_available())'"
      '';

      # GPU smoke test.
      smokeTestPy = pkgs.writeText "torch-cuda-smoke.py" ''
        import sys

        import torch

        print(f"torch {torch.__version__}  (built against cuda {torch.version.cuda})")
        if not torch.cuda.is_available():
            sys.exit("FAIL: torch.cuda.is_available() is False")

        name = torch.cuda.get_device_name(0)
        cap = torch.cuda.get_device_capability(0)
        print(f"device: {name}  capability: {cap[0]}.{cap[1]}")

        a = torch.randn(4096, 4096, device="cuda")
        b = torch.randn(4096, 4096, device="cuda")
        checksum = (a @ b).sum().item()
        torch.cuda.synchronize()
        print(f"cuda matmul checksum: {checksum:.3f}")
        print("CUDA SMOKE TEST PASSED")
      '';

      smokeScript = pkgs.writeShellScriptBin "pytorch-smoke" ''
        # NixOS exposes the NVIDIA driver (libcuda.so.1) here.
        export LD_LIBRARY_PATH="/run/opengl-driver/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        exec ${pythonEnv}/bin/python3 ${smokeTestPy}
      '';
    in
    {
      packages.${system} = {
        inherit torch-cuda;
        python-env = pythonEnv;
        default = pythonEnv;
      };

      apps.${system} = {
        build-torch = {
          type = "app";
          program = "${buildScript}/bin/pytorch-build";
        };
        venv = {
          type = "app";
          program = "${venvScript}/bin/pytorch-venv";
        };
        smoke = {
          type = "app";
          program = "${smokeScript}/bin/pytorch-smoke";
        };
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.uv
          pythonEnv
          buildScript
          venvScript
          smokeScript
        ];
        shellHook = ''
          # Make the NVIDIA driver libraries visible (libcuda.so.1).
          export LD_LIBRARY_PATH="/run/opengl-driver/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
          echo "pytorch+cuda dev shell (torch ${pytorchVersion}, CUDA ${pkgs.cudaPackages.cudaMajorMinorVersion}, arch ${builtins.concatStringsSep "," cudaArchs})"
          echo "  pytorch-build   -> limited-resource build (CORES=N to tune, default 8)"
          echo "  pytorch-venv    -> create ./.venv with uv containing the built torch"
          echo "  pytorch-smoke   -> verify CUDA acceleration"
        '';
      };
    };
}
