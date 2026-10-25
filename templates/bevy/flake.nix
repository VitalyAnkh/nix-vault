# Bevy development shell: `nrust`, or `use flake <this directory>` in a project's .envrc so that
# editors load it through direnv. It brings neither Rust nor a C compiler: rustup (Home Manager)
# provides the toolchain, and cc is the host's (Xcode's Command Line Tools on macOS, the Home
# Manager clang on Linux), so cargo builds the same way inside and outside the shell.
# https://github.com/bevyengine/bevy/blob/main/docs/linux_dependencies.md#nix
{
  description = "Bevy Game Engine - Rust Lang";

  # On Linux the libraries come from this nixpkgs, but cc and glibc from the host: keep the lock at
  # or behind the host's nixpkgs, as libraries built against a newer glibc may not link or load.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = func: nixpkgs.lib.genAttrs systems (system: func nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAllSystems (
        pkgs:
        let
          inherit (pkgs) lib;
          isLinux = pkgs.stdenv.hostPlatform.isLinux;
          libs = [
            pkgs.openssl
          ]
          ++ lib.optionals isLinux (
            with pkgs;
            [
              alsa-lib
              udev
              vulkan-loader
              libx11
              libxcursor
              libxi
              libxrandr
              libxkbcommon
              fontconfig
              wayland
            ]
          );
        in
        {
          default = pkgs.mkShellNoCC (
            {
              packages = with pkgs; [
                pkg-config
                cargo-watch
              ];
              buildInputs = libs;
            }
            // lib.optionalAttrs isLinux {
              # winit and wgpu open X11, Wayland and Vulkan with dlopen.
              LD_LIBRARY_PATH = lib.makeLibraryPath libs;
            }
            // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
              # Darwin's stdenv sets 14.0; unset, rustc targets the same macOS as outside the shell.
              shellHook = "unset MACOSX_DEPLOYMENT_TARGET";
            }
          );
        }
      );
    };
}
