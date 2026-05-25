{
  lib,
  stdenv,
  source-roxy-browser,
  autoPatchelfHook,
  dpkg,
  makeWrapper,
  wrapGAppsHook3,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  glib,
  gtk3,
  libappindicator-gtk3,
  libdrm,
  libgbm,
  libglvnd,
  libnotify,
  libsecret,
  libuuid,
  libxkbcommon,
  libx11,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxrandr,
  libxscrnsaver,
  libxtst,
  libxcb,
  nspr,
  nss,
  pango,
  udev,
  xdg-utils,
  zlib,
}:

let
  runtimeLibs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    glib
    gtk3
    libappindicator-gtk3
    libdrm
    libgbm
    libglvnd
    libnotify
    libsecret
    libuuid
    libxkbcommon
    nspr
    nss
    pango
    stdenv.cc.cc.lib
    udev
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxscrnsaver
    libxtst
    libxcb
    zlib
  ];
in
stdenv.mkDerivation rec {
  pname = "roxy-browser";
  inherit (source-roxy-browser) src version;

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = runtimeLibs;

  dontConfigure = true;
  dontBuild = true;
  dontWrapGApps = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    install -d "$out/share/roxy-browser" "$out/bin"
    cp -a opt/RoxyBrowser/. "$out/share/roxy-browser/"

    install -D -m644 usr/share/applications/roxybrowser.desktop \
      "$out/share/applications/roxybrowser.desktop"
    substituteInPlace "$out/share/applications/roxybrowser.desktop" \
      --replace-fail "/opt/RoxyBrowser/roxybrowser --no-sandbox --disable-setuid-sandbox" \
                     "$out/bin/roxy-browser"

    cp -a usr/share/icons "$out/share/"

    install -D -m644 opt/RoxyBrowser/resources/com.roxybrowser.policy \
      "$out/share/polkit-1/actions/com.roxybrowser.policy"

    runHook postInstall
  '';

  postFixup = ''
    makeWrapper "$out/share/roxy-browser/roxybrowser" "$out/bin/roxy-browser" \
      "''${gappsWrapperArgs[@]}" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibs}:$out/share/roxy-browser" \
      --prefix PATH : "${lib.makeBinPath [ xdg-utils ]}" \
      --add-flags "--no-sandbox" \
      --add-flags "--disable-setuid-sandbox"

    ln -s "$out/bin/roxy-browser" "$out/bin/roxybrowser"
  '';

  meta = {
    description = "Roxy Browser antidetect browser";
    homepage = "https://roxybrowser.com";
    license = lib.licenses.unfreeRedistributable;
    mainProgram = "roxy-browser";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
