{ config, lib, ... }:
{
  options.modules.darwin.upstreamOpenldap = lib.mkEnableOption "nixpkgs' OpenLDAP, with its checks, instead of the shared override that disables them; GnuPG and its consumers then match upstream and come from the binary cache";

  config.nixpkgs.overlays = lib.mkAfter [
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

              # The pinned dbus's session bus listens through launchd on Darwin, which
              # Nix builds cannot use. Run the unchanged tests on a private bus. Newer
              # nixpkgs listens on unix:tmpdir instead; the first assertion detects it.
              jeepney = pythonPrev.jeepney.overridePythonAttrs (
                old:
                let
                  sessionConfig = "${prev.dbus}/share/dbus-1/session.conf";
                  originalConfigFlag = "--config-file=${sessionConfig}";
                  originalCheckPhase = old.checkPhase or "";
                  # Without this flag, dbus keeps its Darwin default, launchd.
                  dbusListensOnLaunchd =
                    !lib.any (lib.hasPrefix "-Ddbus_session_bus_listen_address=") (prev.dbus.mesonFlags or [ ]);
                in
                assert lib.assertMsg dbusListensOnLaunchd
                  "jeepney: nixpkgs' dbus no longer listens through launchd on Darwin; remove this workaround and its darwin-packages check.";
                assert lib.assertMsg
                  (lib.hasInfix (builtins.unsafeDiscardStringContext originalConfigFlag) originalCheckPhase)
                  "jeepney: upstream D-Bus test command changed; update or remove the private session workaround.";
                {
                  preCheck = lib.concatStringsSep "\n" [
                    (old.preCheck or "")
                    ''
                      jeepneyDbusDir="$(mktemp -d "$TMPDIR/jeepney-dbus.XXXXXX")"
                      ln -s ${prev.dbus}/share/dbus-1/session.d "$jeepneyDbusDir/session.d"
                      substitute ${sessionConfig} "$jeepneyDbusDir/session.conf" \
                        --replace-fail \
                        '<listen>launchd:env=DBUS_LAUNCHD_SESSION_BUS_SOCKET</listen>' \
                        "<listen>unix:tmpdir=$jeepneyDbusDir</listen>"
                    ''
                  ];
                  checkPhase =
                    lib.replaceStrings
                      [ originalConfigFlag ]
                      [
                        ''--config-file="$jeepneyDbusDir/session.conf"''
                      ]
                      originalCheckPhase;
                }
              );
            })
          ];
        }
        // lib.optionalAttrs config.modules.darwin.upstreamOpenldap {
          inherit (upstreamPkgs) openldap;
        }
      )
    )
  ];
}
