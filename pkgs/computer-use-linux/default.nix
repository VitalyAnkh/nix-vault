{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  libxkbcommon,
}:
let
  version = "0.7.15";

  # Prebuilt release binaries; the crate is not packaged in nixpkgs.
  assets = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-gnu";
      hash = "sha256-7NBcwxAnoS3h5rTLI61XYEIO8o+co7ewOU+ksm7Zqdk=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-gnu";
      hash = "sha256-/j6H5YyqMp4RN5Vs/22ncFXZdTy/1Dd21HjcRw1AgRo=";
    };
  };

  asset =
    assets.${stdenv.hostPlatform.system}
      or (throw "computer-use-linux: unsupported system ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "computer-use-linux";
  inherit version;

  src = fetchurl {
    url = "https://github.com/agent-sh/computer-use-linux/releases/download/v${version}/computer-use-linux-${asset.target}";
    inherit (asset) hash;
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];
  # It dlopens libxkbcommon to check literal text typed through the GNOME portal,
  # which autoPatchelf cannot see.
  runtimeDependencies = [ libxkbcommon ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/computer-use-linux
    runHook postInstall
  '';

  meta = {
    description = "MCP server and CLI to control a Linux desktop";
    homepage = "https://github.com/agent-sh/computer-use-linux";
    license = lib.licenses.mit;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "computer-use-linux";
  };
}
