{ lib, ... }:
{
  nixpkgs.overlays = lib.mkAfter [
    (
      _final: prev:
      # Cross and static package sets keep their own builds.
      lib.optionalAttrs (lib.systems.equals prev.stdenv.hostPlatform prev.stdenv.buildPlatform) (
        let
          # The pinned nixpkgs without this repository's overlays.
          upstreamPkgs = import prev.path {
            inherit (prev.stdenv.hostPlatform) system;
            inherit (prev) config;
            overlays = [ ];
          };
        in
        {
          # pkgs/nodejs patches Node on Darwin, which changes every package built with
          # it. Reuse upstream builds of packages that need Node only to build: their
          # runtime closures contain no Node. Zotero builds on Firefox ESR and Marksman
          # on .NET, both from source.
          inherit (upstreamPkgs) zotero marksman;

          # Go embeds the static UI; it has no Node runtime dependency.
          argocd = prev.argocd.overrideAttrs (_old: {
            ui = upstreamPkgs.argocd.ui;
          });

          # Azurite is used only by Arrow's install checks.
          arrow-cpp = prev.arrow-cpp.override {
            azurite = upstreamPkgs.azurite;
          };

          pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
            (_pythonFinal: pythonPrev: {
              # Furo's Node build produces only static scripts and styles.
              furo = pythonPrev.furo.override {
                buildNpmPackage = upstreamPkgs.buildNpmPackage;
              };

            })
          ];
        }
      )
    )
  ];
}
