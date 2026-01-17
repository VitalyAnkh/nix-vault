{
  nuenv,
  mylib,
  nix-gaming,
  ...
}@args:
{
  nixpkgs.overlays = [
    nuenv.overlays.default
    nix-gaming.overlays.default
    # nix-vault/modules/overlays has been deleted
    # use nix-vault/modules/pkgs
    (
      final: prev:
      let
        sources = prev.callPackage ../../pkgs/_sources/generated.nix { };
      in
      mylib.callPackageFromDirectory {
        callPackage = prev.lib.callPackageWith (prev // sources);
        directory = ../../pkgs;
      }
    )
    # AUR's cgit endpoint is protected by a bot-check page which breaks fixed-output fetches.
    # Fetch the AUR git repo instead and read the XML from it.
    (final: prev: {
      osu-mime = prev.osu-mime.overrideAttrs (
        _old:
        let
          osu-web-rev = "96e384d5932c0113d1ad8fa8c6ac1052d1e22268";
          osu-mime-spec = prev.fetchgit {
            url = "https://aur.archlinux.org/osu-mime.git";
            rev = "7b5a2d89a10a96b43ef9e37dbcd236d141148e06";
            hash = "sha256-5awqzd05j6lZjZXzx5hKRbTptpinZMBkwMzb1a3WFzg=";
          };
        in
        {
          srcs = [
            (prev.fetchurl {
              url = "https://raw.githubusercontent.com/ppy/osu-web/${osu-web-rev}/public/images/layout/osu-logo-triangles.svg";
              hash = "sha256-4a6vm4H6iOmysy1/fDV6PyfIjfd1/BnB5LZa3Z2noa8=";
            })
            (prev.fetchurl {
              url = "https://raw.githubusercontent.com/ppy/osu-web/${osu-web-rev}/public/images/layout/osu-logo-white.svg";
              hash = "sha256-XvYBIGyvTTfMAozMP9gmr3uYEJaMcvMaIzwO7ZILrkY=";
            })
            (osu-mime-spec + "/osu-file-extensions.xml")
          ];
        }
      );

      # nix-gaming wires osu-lazer-bin against its own osu-mime; re-wire to the overridden one.
      osu-lazer-bin = prev.osu-lazer-bin.override { osu-mime = final.osu-mime; };
      osu-lazer-tachyon-bin = prev.osu-lazer-tachyon-bin.override { osu-mime = final.osu-mime; };
    })

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
  ];
}
