{
  lib,
  pkgs,
  pkgs-master,
  ...
}:
{
  home.packages = with pkgs; [
    #-- nix
    nil
    # rnix-lsp
    # nixd
    statix # Lints and suggestions for the nix programming language
    deadnix # Find and remove unused code in .nix source files
    alejandra # Nix Code Formatter
    nixfmt-tree
    nixfmt # Nix Code Formatter

    # android
    # android-studio-full
    android-studio-tools

    #-- nickel lang
    nickel

    #-- json like
    terraform-ls
    (if stdenv.isLinux then jsonnet else emptyDirectory)
    jsonnet-language-server
    taplo # TOML language server / formatter / validator
    yaml-language-server
    actionlint # GitHub Actions linter

    #-- dockerfile
    hadolint # Dockerfile linter
    dockerfile-language-server

    #-- markdown
    marksman # language server for markdown
    glow # markdown previewer
    pandoc # document converter
    pkgs-master.hugo # static site generator

    #-- sql
    sqlfluff

    #-- protocol buffer
    buf # linting and formatting

    #-- c/c++
    cmake
    cmake-language-server
    gnumake
    checkmake
    # c/c++ compiler, required by nvim-treesitter!
    # gcc
    (if stdenv.isLinux then gdb else emptyDirectory)
    # c/c++ tools with clang-tools, the unwrapped version won't
    # add alias like `cc` and `c++`, so that it won't conflict with gcc
    # llvmPackages.clang-unwrapped
    clang
    mold
    sccache
    clang-tools
    lldb

    deno

    #-- python
    uv # python project package manager
    (python313.withPackages (
      ps: with ps; [
        # python language server
        ty
        ruff

        # my commonly used python packages
        jupyter
        ipython
        pandas
        numpy
        requests
        pyquery
        pyyaml
        protobuf # protocol buffer compiler
      ]
    ))

    #-- rust
    # we'd better use the rust-overlays for rust development
    # pkgs-master.rustc
    # pkgs-master.rust-analyzer
    # pkgs-master.cargo # rust package manager
    # pkgs-master.rustfmt
    # pkgs-master.clippy # rust linter
    rustup
    elan

    #-- golang
    go
    gomodifytags
    iferr # generate error handling code for go
    impl # generate function implementation for go
    (lib.lowPrio gotools) # also ships modernize; let gopls provide that binary.
    gopls # go language server
    delve # go debugger

    # -- java
    jdk25
    gradle
    maven
    spring-boot-cli
    jdt-language-server

    #-- zig
    (if stdenv.isLinux then zls else emptyDirectory)

    #-- lua
    stylua
    lua-language-server

    devenv

    #-- bash
    bash-language-server
    shellcheck
    shfmt

    #-- web development
    nodejs
    typescript
    typescript-language-server
    # HTML/CSS/JSON/ESLint language servers extracted from vscode
    vscode-langservers-extracted
    tailwindcss-language-server
    emmet-ls

    # -*- Lisp like Languages -*-#
    guile
    (if stdenv.isLinux then racket-minimal else emptyDirectory)
    fnlfmt # fennel
    (
      if pkgs.stdenv.isLinux && pkgs.stdenv.hostPlatform.isx86 then
        pkgs-master.akkuPackages.scheme-langserver
      else
        pkgs.emptyDirectory
    )

    proselint # English prose linter
    typst
    tinymist

    #-- verilog / systemverilog
    (if stdenv.isLinux then verible else emptyDirectory)

    #-- Optional Requirements:
    prettier # common code formatter
    fzf
    gdu # disk usage analyzer, required by AstroNvim
    (ripgrep.override { withPCRE2 = true; }) # recursively searches directories for a regex pattern
  ];
}
