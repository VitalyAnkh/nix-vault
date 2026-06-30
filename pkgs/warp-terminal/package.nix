{
  crane,
  lib,
  nixpkgs,
  rust-overlay,
  source-warp-terminal,
  stdenv,
  ...
}:

let
  system = stdenv.hostPlatform.system;
  upstreamSource = source-warp-terminal.src;
  upstreamFlake = import "${upstreamSource}/flake.nix";
  upstreamOutputs = upstreamFlake.outputs {
    self = {
      outPath = upstreamSource;
      rev = source-warp-terminal.version;
      shortRev = builtins.substring 0 7 source-warp-terminal.version;
    };
    inherit nixpkgs crane rust-overlay;
  };
  upstreamPackagePath = [
    "packages"
    system
    "warp-terminal-experimental"
  ];
  upstreamPackage = lib.attrByPath upstreamPackagePath null upstreamOutputs;

  unsupportedPackage = stdenv.mkDerivation {
    pname = "warp-terminal";
    version = "unsupported";

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      echo "warp-terminal is only supported on Linux systems with upstream Warp flake support; no upstream package exists for ${system}" >&2
      exit 1
    '';

    meta = with lib; {
      description = "Warp is an agentic development environment, born out of the terminal";
      homepage = "https://github.com/warpdotdev/Warp";
      license = licenses.agpl3Only;
      mainProgram = "warp-terminal";
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      broken = true;
      sourceProvenance = with sourceTypes; [ fromSource ];
    };
  };
in
if upstreamPackage == null then
  unsupportedPackage
else
  upstreamPackage.overrideAttrs (old: {
    pname = "warp-terminal";

    meta = (old.meta or { }) // {
      description = "Warp is an agentic development environment, born out of the terminal";
      homepage = "https://github.com/warpdotdev/Warp";
      # Upstream's Linux flake currently builds the OSS channel binary. Keep
      # the historical package name/aliases, but expose the real desktop app
      # entrypoint so launchers and `lib.getExe` do not route through the
      # experimental alias.
      mainProgram = "warp-oss";
    };

    postInstall = (old.postInstall or "") + ''
      desktop_entry="$out/share/applications/dev.warp.WarpOss.desktop"
      if [ ! -f "$desktop_entry" ]; then
        echo "expected Warp OSS desktop entry is missing: $desktop_entry" >&2
        exit 1
      fi

      substituteInPlace "$desktop_entry" \
        --replace-fail "Name=WarpOss" "Name=Warp (OSS)" \
        --replace-fail "Exec=warp-terminal-experimental %U" "Exec=warp-oss %U"

      ln -sfn "$out/bin/warp-terminal-experimental" "$out/bin/warp-terminal"
    '';
  })
