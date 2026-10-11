{
  lib,
  outputs,
}:
lib.genAttrs (builtins.attrNames outputs.darwinConfigurations) (
  name:
  let
    inherit (outputs.darwinConfigurations.${name}) pkgs;
    upstreamPkgs = import pkgs.path {
      inherit (pkgs.stdenv.hostPlatform) system;
      inherit (pkgs) config;
      overlays = [ ];
    };
    isUpstream = package: upstreamPackage: package.drvPath == upstreamPackage.drvPath;
  in
  {
    # pkgs/nodejs backports V8's std::hash fix on Darwin.
    nodejsHasV8Fix = builtins.any (
      patch: lib.hasSuffix "/v8-std-hash.patch" (toString patch)
    ) pkgs.nodejs-slim_24.patches;
    # pkgs/emacs builds the IGC Emacs as the NS port on Darwin and backports
    # bug#81906, without which Doom cannot generate its autoloads.
    emacsIsNs = pkgs.emacs-master-pgtk-with-igc.pname == "emacs-master-ns-with-igc";
    emacsHasAutoloadFix = builtins.any (
      patch: lib.hasSuffix "/make-autoload-arglist.patch" (toString patch)
    ) pkgs.emacs-master-pgtk-with-igc.patches;
    # pkgs/android-studio-tools installs Google's macOS command-line tools archive.
    androidToolsUseMacArchive = builtins.any (lib.hasInfix "commandlinetools-mac-") pkgs.android-studio-tools.src.urls;
    # modules/darwin/overlays.nix: packages that need Node only to build keep
    # their upstream builds instead of being rebuilt with the patched Node.
    nodeBuildUsersFromUpstream = {
      zotero = isUpstream pkgs.zotero upstreamPkgs.zotero;
      marksman = isUpstream pkgs.marksman upstreamPkgs.marksman;
      argocdUi = isUpstream pkgs.argocd.ui upstreamPkgs.argocd.ui;
      arrowAzurite = builtins.any (
        input: (input.drvPath or null) == upstreamPkgs.azurite.drvPath
      ) pkgs.arrow-cpp.nativeBuildInputs;
      furo = isUpstream pkgs.python3Packages.furo upstreamPkgs.python3Packages.furo;
    };
    jeepneyPrivateBus = lib.hasInfix "jeepneyDbusDir" pkgs.python3Packages.jeepney.preCheck;
    openldapUsesUpstream = isUpstream pkgs.openldap upstreamPkgs.openldap;
  }
)
