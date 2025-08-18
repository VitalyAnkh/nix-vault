{
  description = "Example C++ development environment for Zero to Nix";

  # Flake inputs
  inputs = {
    # Latest stable Nixpkgs
    # nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  # Flake outputs
  outputs =
    {
      self,
      nixpkgs,
    }:
    let
      # Systems supported
      allSystems = [
        "x86_64-linux" # 64-bit Intel/AMD Linux
        "aarch64-linux" # 64-bit ARM Linux
        "x86_64-darwin" # 64-bit Intel macOS
        "aarch64-darwin" # 64-bit ARM macOS
      ];

      # Helper to provide system-specific attributes
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs allSystems (
          system:
          f {
            pkgs = import nixpkgs {
              inherit system;
              config.allowUnfree = true;
              config.cudaSupport = true;
              config.cudaVersion = "12";
            };
          }
        );
      clangDrv = nixpkgs.runCommand "local-clang" { } ''
        mkdir -p $out/bin
        cp ${./build/bin/clang} $out/bin/
      '';
      customStdenv = nixpkgs.overrideCC nixpkgs.stdenv clangDrv;
    in
    {
      # Development environment output
      devShells = forAllSystems (
        { pkgs }:
        {
          default = pkgs.mkShell {
            # stdenv = customStdenv;
            stdenv = pkgs.clangStdenv;
            # The Nix packages provided in the environment
            packages = with pkgs; [
              boost # The Boost libraries
              ccache
              # stdenv.cc
              # gcc # The GNU Compiler Collection
              gcc_multi
              glibc_multi
              glibc
              # glibc.dev
              clang
              # llvmPackages_20.clang
              # pkgs-stable.cmake
              python313Packages.cmake
              ninja
              ffmpeg
              fmt.dev
              cudaPackages.cuda_cudart
              cudaPackages.cudnn
              cudatoolkit
              linuxPackages.nvidia_x11
              mold
              libGLU
              libGL
              glfw
              sccache
              xorg.libXi
              xorg.libXmu
              freeglut
              xorg.libXext
              xorg.libX11
              xorg.libXv
              xorg.libXrandr
              zlib
              ncurses5
              binutils
              uv
              vulkan-volk
              vulkan-tools
              vulkan-loader
              vulkan-helper
              vulkan-validation-layers
              vulkan-utility-libraries
              python313Packages.pybind11
              python313Packages.nanobind
              pkg-config
            ];

            shellHook = ''
              export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib.outPath}/lib:${pkgs.linuxPackages.nvidia_x11}/lib:${pkgs.zlib}/lib:$LD_LIBRARY_PATH"
              export CUDA_PATH=${pkgs.cudatoolkit}
              export EXTRA_LDFLAGS="-L/lib -L${pkgs.linuxPackages.nvidia_x11}/lib"
              export EXTRA_CCFLAGS="-I/usr/include -isystem ${pkgs.glibc_multi.dev}/include"
              export CMAKE_PREFIX_PATH="${pkgs.glfw}:${pkgs.fmt.dev}:$CMAKE_PREFIX_PATH"
              export PKG_CONFIG_PATH="${pkgs.glfw}/lib/pkgconfig:${pkgs.fmt.dev}/lib/pkgconfig:$PKG_CONFIG_PATH"
              # export NIX_CFLAGS_COMPILE=" -isystem ${pkgs.glibc.dev}/include -isystem ${pkgs.glibc_multi.dev}/include $NIX_CFLAGS_COMPILE"
              export NIX_LDFLAGS="-L${pkgs.glibc_multi.out}/lib $NIX_LDFLAGS"
              # export CPLUS_INCLUDE_PATH="${pkgs.stdenv.cc.cc}/include/c++/${pkgs.stdenv.cc.cc.version}:${pkgs.stdenv.cc.cc}/include/c++/${pkgs.stdenv.cc.cc.version}/x86_64-unknown-linux-gnu"
              # export CPATH="${pkgs.glibc.dev}/include:$CPATH"
              export CUDAFLAGS+=" -idirafter ${pkgs.glibc.dev}/include"
              # export LLVM_CLANG_PATH="${pkgs.clang}/bin/clang++"
              export NVCC_CCBIN="${pkgs.clang}/bin/clang++"
              # export NVCC_CCBIN="${pkgs.gcc}/bin/g++"
              export CUDAHOSTCXX="${pkgs.clang}/bin/clang++"
              export NIX_NVCC_FLAGS=" -isystem ${pkgs.glibc.dev}/include"
            '';

          };
        }
      );
    };
}
