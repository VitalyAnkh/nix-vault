{
  self,
  nixpkgs,
  pre-commit-hooks,
  ...
}@inputs:
let
  inherit (inputs.nixpkgs) lib;
  mylib = import ../lib { inherit lib; };
  myvars = import ../vars { inherit lib; };

  # Add my custom lib, vars, nixpkgs instance, and all the inputs to specialArgs,
  # so that I can use them in all my nixos/home-manager/darwin modules.
  genSpecialArgs =
    system:
    inputs
    // {
      inherit mylib myvars;

      # use unstable branch for some packages to get the latest updates
      # pkgs-unstable = import inputs.nixpkgs-unstable {
      #   inherit system; # refer the `system` parameter form outer scope recursively
      #   # To use chrome, we need to allow the installation of non-free software
      #   config.allowUnfree = true;
      # };
      pkgs-2505 = import inputs.nixpkgs-2505 {
        inherit system;
        # To use chrome, we need to allow the installation of non-free software
        config.allowUnfree = true;
      };
      pkgs-stable = import inputs.nixpkgs-stable {
        inherit system;
        # To use chrome, we need to allow the installation of non-free software
        config.allowUnfree = true;
      };
      pkgs-patched = import inputs.nixpkgs-patched {
        inherit system;
        # to use chrome, we need to allow the installation of non-free software
        config.allowUnfree = true;
      };
      pkgs-master = import inputs.nixpkgs-master {
        inherit system;
        # to use chrome, we need to allow the installation of non-free software
        config.allowUnfree = true;
      };

      pkgs-x64 = import nixpkgs {
        system = "x86_64-linux";

        # To use chrome, we need to allow the installation of non-free software
        config.allowUnfree = true;

      };

      # Some modules expect this input to exist in specialArgs even when the flake input
      # is not configured in `flake.nix` (e.g. on machines that don't need Asahi firmware).
      my-asahi-firmware =
        if builtins.hasAttr "my-asahi-firmware" inputs then inputs."my-asahi-firmware" else null;
    };

  # This is the args for all the haumea modules in this folder.
  args = {
    inherit
      inputs
      lib
      mylib
      myvars
      genSpecialArgs
      ;
  };

  # modules for each supported system
  nixosSystems = {
    x86_64-linux = import ./x86_64-linux (args // { system = "x86_64-linux"; });
    aarch64-linux = import ./aarch64-linux (args // { system = "aarch64-linux"; });
    # riscv64-linux = import ./riscv64-linux (args // {system = "riscv64-linux";});
  };
  darwinSystems = {
    aarch64-darwin = import ./aarch64-darwin (args // { system = "aarch64-darwin"; });
  };
  allSystems = nixosSystems // darwinSystems;
  allSystemNames = builtins.attrNames allSystems;
  nixosSystemValues = builtins.attrValues nixosSystems;
  darwinSystemValues = builtins.attrValues darwinSystems;
  allSystemValues = nixosSystemValues ++ darwinSystemValues;

  # Helper function to generate a set of attributes for each system
  forAllSystems = func: (nixpkgs.lib.genAttrs allSystemNames func);
in
{
  # Add attribute sets into outputs, for debugging
  debugAttrs = {
    inherit
      nixosSystems
      darwinSystems
      allSystems
      allSystemNames
      ;
  };

  # NixOS Hosts
  nixosConfigurations = lib.attrsets.mergeAttrsList (
    map (it: it.nixosConfigurations or { }) nixosSystemValues
  );

  # Colmena - remote deployment via SSH
  colmena = {
    meta =
      (
        let
          system = "x86_64-linux";
        in
        {
          # colmena's default nixpkgs & specialArgs
          nixpkgs = import nixpkgs { inherit system; };
          specialArgs = genSpecialArgs system;
        }
      )
      // {
        # per-node nixpkgs & specialArgs
        nodeNixpkgs = lib.attrsets.mergeAttrsList (
          map (it: it.colmenaMeta.nodeNixpkgs or { }) nixosSystemValues
        );
        nodeSpecialArgs = lib.attrsets.mergeAttrsList (
          map (it: it.colmenaMeta.nodeSpecialArgs or { }) nixosSystemValues
        );
      };
  }
  // lib.attrsets.mergeAttrsList (map (it: it.colmena or { }) nixosSystemValues);

  # macOS Hosts
  darwinConfigurations = lib.attrsets.mergeAttrsList (
    map (it: it.darwinConfigurations or { }) darwinSystemValues
  );

  # Home Manager configurations (standalone)
  homeConfigurations = lib.attrsets.mergeAttrsList (
    map (it: it.homeConfigurations or { }) allSystemValues
  );

  # Packages
  # Collect packages from per-arch outputs and also from the repo's pkgs directory.
  packages = forAllSystems (
    system:
    let
      # Import appropriate nixpkgs for the target system
      nixpkgsFor =
        if (lib.strings.hasInfix "darwin" system) then inputs.nixpkgs-darwin else inputs.nixpkgs;
      pkgs = import nixpkgsFor {
        inherit system;
        config.allowUnfree = true;
      };

      # Generated sources for pkgs/_sources
      sources = pkgs.callPackage ../pkgs/_sources/generated.nix { };

      # Load all packages defined under ./pkgs as a flat attrset
      repoPkgs = mylib.callPackageFromDirectory {
        callPackage = pkgs.lib.callPackageWith (pkgs // sources // (genSpecialArgs system));
        directory = ../pkgs;
      };

      archPkgs = allSystems.${system}.packages or { };
    in
    archPkgs // repoPkgs
  );

  # Eval Tests for all NixOS & darwin systems.
  evalTests = lib.lists.all (it: it.evalTests == { }) allSystemValues;

  checks = forAllSystems (
    system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
      evalResult = allSystems.${system}.evalTests;
      okDrv = pkgs.runCommand "eval-tests-${system}" { } ''
        echo ok > "$out"
      '';
      failDrv = pkgs.runCommand "eval-tests-${system}-failed" { } ''
        echo "Eval tests failed for ${system}" >&2
        echo '${builtins.toJSON evalResult}' >&2
        exit 1
      '';
    in
    {
      # Wrap eval-tests result as a derivation for flake checks
      eval-tests = if evalResult == { } then okDrv else failDrv;

      pre-commit-check = pre-commit-hooks.lib.${system}.run {
        src = mylib.relativeToRoot ".";
        hooks = {
          nixfmt-rfc-style = {
            enable = true;
            settings.width = 100;
          };
          # Source code spell checker
          typos = {
            enable = true;
            settings = {
              write = true; # Automatically fix typos
              # NOTE: git-hooks.nix currently generates a config file in the Nix store for the `typos`
              # hook, so `configPath` may not be used even when set. Read the repo config and pass the
              # parsed TOML as structured config to ensure project-specific words like `osu-lazer` stay
              # intact.
              config = builtins.fromTOML (builtins.readFile (mylib.relativeToRoot ".typos.toml"));
              exclude = "(^rime-data/|^home/base/tui/editors/emacs/doom/init\\.el$|^home/linux/gui/base/fcitx5/pinyin\\.conf$)";
            };
          };
          prettier = {
            enable = true;
            settings = {
              write = true; # Automatically format files
              configPath = ".prettierrc.yaml"; # relative to the flake root
            };
          };
          # deadnix.enable = true; # detect unused variable bindings in `*.nix`
          # statix.enable = true; # lints and suggestions for Nix code(auto suggestions)
        };
      };
    }
  );

  # Development Shells
  devShells = forAllSystems (
    system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      default = pkgs.mkShell {
        packages = with pkgs; [
          # fix https://discourse.nixos.org/t/non-interactive-bash-errors-from-flake-nix-mkshell/33310
          bashInteractive
          # fix `cc` replaced by clang, which causes nvim-treesitter compilation error
          gcc
          # Nix-related
          nixfmt
          deadnix
          statix
          # spell checker
          typos
          # code formatter
          prettier
        ];
        name = "dots";
        inherit (self.checks.${system}.pre-commit-check) shellHook;
      };
    }
  );

  # Format the nix code in this flake
  formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
}
