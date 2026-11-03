{
  nixpkgs,
  mylib,
  crane,
  rust-overlay,
  ...
}@args:
{
  # ../../overlays as upstream applies them (the nur-ryan4yin packages), then the
  # local overlays; pkgs/ comes later, so its computer-use-linux and cua-driver
  # replace NUR's.
  nixpkgs.overlays = import ../../overlays args ++ [
    # nix-vault/modules/overlays has been deleted
    # use nix-vault/modules/pkgs
    (
      final: prev:
      let
        sources = prev.callPackage ../../pkgs/_sources/generated.nix { };
      in
      mylib.callPackageFromDirectory {
        callPackage = final.lib.callPackageWith (
          final
          // prev
          // sources
          // {
            inherit
              nixpkgs
              crane
              rust-overlay
              ;
          }
        );
        directory = ../../pkgs;
      }
    )
    # nixpkgs: umu-launcher currently fails versionCheckPhase because `version` is set to a git rev
    # while `umu-run --version` prints a semver (e.g. 1.3.0). Disable installCheck to unblock builds.
    (final: prev: {
      umu-launcher-unwrapped = prev.umu-launcher-unwrapped.overrideAttrs (_old: {
        doInstallCheck = false;
      });

      # Make sure the wrapper package picks up the overridden unwrapped derivation.
      umu-launcher = prev.umu-launcher.override {
        umu-launcher-unwrapped = final.umu-launcher-unwrapped;
      };
    })

    # Warzone 2100 4.7.0 uses a Vulkan-Hpp enum alias removed in Vulkan 1.4.350.
    # Backport the upstream compatibility fix until nixpkgs includes it. The
    # games module takes Warzone from nixpkgs 26.05 (Vulkan 1.4.341) for now,
    # while GCC 16 fails to build it in unstable.
    (_final: prev: {
      warzone2100 = prev.warzone2100.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          (prev.fetchurl {
            url = "https://github.com/Warzone2100/warzone2100/commit/8701c62ae68ca70da43ec915cbf6776c492e6656.patch";
            hash = "sha256-LIPoGQ8ZloqD20JkptsHK0mhnfjcJCCLMeshhzsmqjY=";
          })
        ];
      });
    })

    # cli-helpers 2.10.0 has color-sequence assertions that no longer match
    # current Pygments output, which breaks mycli/pgcli builds.
    (final: prev: {
      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
        (_python-final: python-prev: {
          "cli-helpers" = python-prev."cli-helpers".overridePythonAttrs (old: {
            disabledTests = (old.disabledTests or [ ]) ++ [
              "test_style_output"
              "test_style_output_with_newlines"
              "test_style_output_custom_tokens"
            ];
          });
        })
      ];
    })

    # pipx 1.8.0 tests still expect the old no-space spelling around PEP 508
    # direct references; current packaging normalizes them with spaces.
    (final: prev: {
      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
        (_python-final: python-prev: {
          pipx = python-prev.pipx.overridePythonAttrs (old: {
            disabledTests = (old.disabledTests or [ ]) ++ [
              "test_fix_package_name"
              "test_parse_specifier_for_metadata"
            ];
          });
        })
      ];
    })
  ];
}
