{
  lib,
  appimageTools,
  source-bambu-studio,
}:
let
  pname = "bambu-studio";
  # nvfetcher's version is the release asset path,
  # "v<version>/BambuStudio_ubu24-v<version>-<build>".
  version = lib.removePrefix "v" (builtins.head (lib.splitString "/" source-bambu-studio.version));
  inherit (source-bambu-studio) src;
  appimageContents = appimageTools.extract { inherit pname version src; };
in
# The official AppImage, unlike nixpkgs' source build, ships the device_page
# web bundle that filament management loads.
appimageTools.wrapType2 {
  inherit pname version src;

  extraPkgs = pkgs: [
    # Linked by the binary but not bundled in the AppImage.
    pkgs.webkitgtk_4_1
    # TLS for WebKit's libsoup (login, MakerWorld) and the camera stream's
    # GStreamer plugins, as in nixpkgs' source build.
    pkgs.glib-networking
    pkgs.gst_all_1.gst-plugins-good
    pkgs.gst_all_1.gst-plugins-bad
  ];

  # buildFHSEnv sets GST_PLUGIN_SYSTEM_PATH_1_0 but not the GIO module path.
  profile = ''
    export GIO_EXTRA_MODULES=/usr/lib/gio/modules''${GIO_EXTRA_MODULES:+:$GIO_EXTRA_MODULES}
  '';

  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/BambuStudio.desktop -t $out/share/applications
    substituteInPlace $out/share/applications/BambuStudio.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=bambu-studio'
    cp -r ${appimageContents}/usr/share/icons $out/share/icons
  '';

  meta = {
    description = "PC software for Bambu Lab 3D printers (official AppImage)";
    homepage = "https://github.com/bambulab/BambuStudio";
    changelog = "https://github.com/bambulab/BambuStudio/releases/tag/v${version}";
    license = lib.licenses.agpl3Plus;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "bambu-studio";
  };
}
