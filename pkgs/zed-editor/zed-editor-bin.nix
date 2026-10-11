{
  lib,
  stdenvNoCC,
  fetchurl,
  _7zz,
}:
let
  arch = stdenvNoCC.hostPlatform.parsed.cpu.name;
  hashes = {
    aarch64 = "sha256-Dcir+ZSOqj4+Xnb/db9TfZO7bx0qV/vaL3zHO/jSgFU=";
    x86_64 = "sha256-QlTXpds6+GM25ffWjWct+DM7UtM9K2/IcA+6lTwjpus=";
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "zed-editor-bin";
  version = "1.9.0";

  src = fetchurl {
    url = "https://github.com/zed-industries/zed/releases/download/v${finalAttrs.version}/Zed-${arch}.dmg";
    hash = hashes.${arch};
  };

  nativeBuildInputs = [ _7zz ];
  sourceRoot = ".";
  # The official DMG uses APFS; extract only its signed application bundle.
  unpackPhase = ''
    runHook preUnpack
    7zz x "$src" 'Zed.app/*'
    runHook postUnpack
  '';
  dontConfigure = true;
  dontBuild = true;
  # Preserve the official bundle's signatures, including its CLI and bundled Git.
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications" "$out/bin"
    cp -R Zed.app "$out/Applications/"

    # The CLI resolves its physical location to find the containing .app bundle.
    ln -s "$out/Applications/Zed.app/Contents/MacOS/cli" "$out/bin/zed"
    ln -s "$out/Applications/Zed.app/Contents/MacOS/cli" "$out/bin/zeditor"

    runHook postInstall
  '';

  doInstallCheck = true;
  # Running the signed app during the build can make macOS protect the bundle
  # before Nix canonicalises the output's metadata, so these checks stay static.
  installCheckPhase = ''
    runHook preInstallCheck

    test -f "$out/Applications/Zed.app/Contents/Info.plist"
    for executable in zed cli git; do
      test -x "$out/Applications/Zed.app/Contents/MacOS/$executable"
    done
    test "$(readlink "$out/bin/zed")" = "$out/Applications/Zed.app/Contents/MacOS/cli"
    test "$(readlink "$out/bin/zeditor")" = "$out/Applications/Zed.app/Contents/MacOS/cli"

    # plutil and codesign come with macOS in /usr/bin, which the Darwin build
    # sandbox hides; Nix's Darwin default (sandbox = false) runs these checks.
    if [ -x /usr/bin/plutil ] && [ -x /usr/bin/codesign ]; then
      test "$(/usr/bin/plutil -extract CFBundleShortVersionString raw -o - \
        "$out/Applications/Zed.app/Contents/Info.plist")" = "${finalAttrs.version}"
      /usr/bin/codesign --verify --deep --strict "$out/Applications/Zed.app"
    else
      echo "skipping version and signature checks: the build sandbox hides /usr/bin"
    fi

    runHook postInstallCheck
  '';

  meta = {
    description = "Zed's official macOS application and command-line launcher";
    longDescription = ''
      The signed upstream application retains remote development support and
      manages remote server downloads itself. This package does not provide a
      separate remote_server output.
    '';
    homepage = "https://zed.dev";
    changelog = "https://github.com/zed-industries/zed/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.gpl3Only;
    mainProgram = "zed";
    platforms = lib.platforms.darwin;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
