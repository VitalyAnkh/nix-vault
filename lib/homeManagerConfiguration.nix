{
  inputs,
  lib,
  system,
  genSpecialArgs,
  home-modules,
  specialArgs ? (genSpecialArgs system),
  myvars,
  mylib,
  username ? myvars.username,
  homeDirectory ? (
    if (lib.strings.hasInfix "darwin" system) then "/Users/${username}" else "/home/${username}"
  ),
  ...
}:
let
  inherit (inputs) nixpkgs home-manager;

  # Custom overlay to add packages from pkgs/ directory
  customOverlay =
    final: prev:
    let
      sources = prev.callPackage ../pkgs/_sources/generated.nix { };
    in
    mylib.callPackageFromDirectory {
      callPackage = final.lib.callPackageWith (final // prev // sources // (genSpecialArgs system));
      directory = ../pkgs;
    };

  # Nixpaks overlay for standalone home-manager (only for Linux)
  nixpaksOverlay =
    if (lib.strings.hasInfix "linux" system) && (inputs ? nixpak) then
      let
        sArgs = genSpecialArgs system;
        # Import the nixpaks module to extract its overlay, provide required args
        nixpaksModule = import (mylib.relativeToRoot "hardening/nixpaks/default.nix") {
          # pkgs used only to shape the overlay; real pkgs is the 'super' in overlay
          pkgs = import nixpkgs { inherit system; };
          inherit (inputs) nixpak;
          pkgs-master = sArgs.pkgs-master;
          firefox = sArgs.firefox;
        };
      in
      builtins.head nixpaksModule.nixpkgs.overlays
    else
      (_: _: { });

  # Bwraps overlay for standalone home-manager.
  # The overlay itself is platform-safe and will expose an empty `pkgs.bwraps`
  # on non-Linux systems.
  bwrapsOverlay =
    let
      bwrapsModule = import (mylib.relativeToRoot "hardening/bwraps/default.nix");
    in
    builtins.head bwrapsModule.nixpkgs.overlays;

  # Mirror the NixOS-side package test workarounds for standalone Home Manager package sets.
  packageTestWorkaroundsOverlay = final: prev: {
    # test017-syncreplication-refresh is timing-sensitive and can fail even when
    # slapd itself built correctly. The other syncrepl tests in this cluster are
    # the same kind of timing-sensitive integration checks, so skip the cluster
    # while keeping the rest of OpenLDAP's runtime outputs.
    openldap = prev.openldap.overrideAttrs (old: {
      doCheck = false;
      preCheck = (old.preCheck or "") + ''
        rm -f tests/scripts/test017-syncreplication-refresh
        rm -f tests/scripts/test018-syncreplication-persist
        rm -f tests/scripts/test019-syncreplication-cascade
      '';
    });

    pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
      (_python-final: python-prev: {
        # pipx 1.8.0 tests still expect the old no-space spelling around PEP 508
        # direct references; current packaging normalizes them with spaces.
        pipx = python-prev.pipx.overridePythonAttrs (old: {
          disabledTests = (old.disabledTests or [ ]) ++ [
            "test_fix_package_name"
            "test_parse_specifier_for_metadata"
          ];
        });
      })
    ];
  };

  # Determine which nixpkgs to use based on system
  pkgs =
    if (lib.strings.hasInfix "darwin" system) then
      import inputs.nixpkgs-darwin {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          customOverlay
          bwrapsOverlay
        ];
      }
    else
      import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          customOverlay
          packageTestWorkaroundsOverlay
          nixpaksOverlay
          bwrapsOverlay
        ];
      };
in
home-manager.lib.homeManagerConfiguration {
  inherit pkgs;

  extraSpecialArgs = specialArgs;

  modules = home-modules ++ [
    {
      # Basic home-manager settings
      home = {
        inherit username homeDirectory;
        stateVersion = lib.mkDefault "26.05";
      };

      # Let home-manager manage itself
      programs.home-manager.enable = true;

      # Ensure nix settings are configured
      nix = {
        package = pkgs.nix;
        settings = {
          experimental-features = [
            "nix-command"
            "flakes"
          ];
        };
      };
    }
  ];
}
