{
  jq,
  lib,
  nixpkgs,
  patchelf,
  rustPlatform,
  source-codex-desktop-linux,
  stdenv,
  ...
}:

let
  system = stdenv.hostPlatform.system;
  upstreamSource = source-codex-desktop-linux.src;
  upstreamFlake = import "${upstreamSource}/flake.nix";
  upstreamOutputs = upstreamFlake.outputs {
    self = {
      outPath = upstreamSource;
    };
    inherit nixpkgs;
    flake-utils.lib.eachSystem = systems: f: lib.genAttrs systems f;
  };
  upstreamPackagePath = [
    system
    "packages"
    "codex-desktop-computer-use-ui"
  ];
  upstreamPackage = lib.attrByPath upstreamPackagePath null upstreamOutputs;
  computerUsePluginSource = "${upstreamSource}/plugins/openai-bundled/plugins/computer-use";

  computerUseBackend = rustPlatform.buildRustPackage {
    pname = "codex-computer-use-linux";
    version = "0.1.2-linux-alpha1";
    src = upstreamSource;

    cargoLock = {
      lockFile = "${upstreamSource}/Cargo.lock";
      outputHashes = {
        "cosmic-protocols-0.2.0" = "sha256-ymn+BUTTzyHquPn4hvuoA3y1owFj8LVrmsPu2cdkFQ8=";
      };
    };
    buildAndTestSubdir = "computer-use-linux";
    cargoBuildFlags = [
      "-p"
      "codex-computer-use-linux"
    ];
    doCheck = false;

    meta = with lib; {
      description = "Rust MCP backend for Codex Desktop Linux Computer Use";
      homepage = "https://github.com/ilysenko/codex-desktop-linux";
      license = licenses.mit;
      mainProgram = "codex-computer-use-linux";
      platforms = [ "x86_64-linux" ];
    };
  };

  unsupportedPackage = stdenv.mkDerivation {
    pname = "codex-desktop";
    version = "unsupported";

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      echo "codex-desktop is only supported on x86_64-linux; no upstream package exists for ${system}" >&2
      exit 1
    '';

    meta = with lib; {
      description = "Codex Desktop with Linux Computer Use bundled resources restored";
      homepage = "https://github.com/ilysenko/codex-desktop-linux";
      license = licenses.mit;
      mainProgram = "codex-desktop";
      platforms = [ "x86_64-linux" ];
      broken = true;
    };
  };
in
if upstreamPackage == null then
  unsupportedPackage
else
  stdenv.mkDerivation {
    pname = "codex-desktop";
    version = upstreamPackage.version or "26.506.21252";
    src = upstreamPackage;

    nativeBuildInputs = [
      jq
      patchelf
    ];

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      cp -aT "$src" "$out"
      chmod -R u+w "$out"

      # The copied launchers still point at the upstream package output; repoint
      # only those references so the bundled resource edits under $out are used.
      substituteInPlace "$out/bin/codex-desktop" \
        --replace-fail "$src" "$out"
      substituteInPlace "$out/share/applications/codex-desktop.desktop" \
        --replace-fail "$src" "$out"

      electron="$out/opt/codex-desktop/electron"
      electronRpath="$(patchelf --print-rpath "$electron")"
      patchelf --set-rpath "''${electronRpath//$src/$out}" "$electron"

      pluginRoot="$out/opt/codex-desktop/resources/plugins/openai-bundled/plugins/computer-use"
      rm -rf "$pluginRoot"
      cp -aT "${computerUsePluginSource}" "$pluginRoot"
      chmod -R u+w "$pluginRoot"
      rm -rf "$pluginRoot/bin"
      mkdir -p "$pluginRoot/bin"
      install -Dm644 "${upstreamSource}/assets/codex.png" \
        "$pluginRoot/assets/app-icon.png"
      install -Dm755 "${computerUseBackend}/bin/codex-computer-use-linux" \
        "$pluginRoot/bin/codex-computer-use-linux"
      install -Dm755 "${computerUseBackend}/bin/codex-computer-use-cosmic" \
        "$pluginRoot/bin/codex-computer-use-cosmic"

      gnomeExtensionRoot="$out/share/gnome-shell/extensions/codex-window-control@openai.com"
      install -Dm644 "${upstreamSource}/computer-use-linux/gnome-shell-extension/metadata.json" \
        "$gnomeExtensionRoot/metadata.json"
      install -Dm644 "${upstreamSource}/computer-use-linux/gnome-shell-extension/extension.js" \
        "$gnomeExtensionRoot/extension.js"

      marketplace="$out/opt/codex-desktop/resources/plugins/openai-bundled/.agents/plugins/marketplace.json"
      tmpMarketplace="$marketplace.tmp"
      jq '
        .plugins = (
          [.plugins[]? | select(.name != "computer-use")]
          + [{
            name: "computer-use",
            source: {
              source: "local",
              path: "./plugins/computer-use"
            },
            policy: {
              installation: "AVAILABLE",
              authentication: "ON_INSTALL"
            },
            category: "Productivity"
          }]
        )
      ' "$marketplace" > "$tmpMarketplace"
      mv "$tmpMarketplace" "$marketplace"

      runHook postInstall
    '';

    meta = with lib; {
      description = "Codex Desktop with Linux Computer Use bundled resources restored";
      homepage = "https://github.com/ilysenko/codex-desktop-linux";
      license = licenses.mit;
      mainProgram = "codex-desktop";
      platforms = [ "x86_64-linux" ];
    };
  }
