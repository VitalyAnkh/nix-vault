{
  stdenv,
  fetchzip,
  jdk,
  gtk3,
  cairo,
  libGLU,
  python3,
  makeWrapper,
  wrapGAppsHook3,
  gobject-introspection,
  libnotify,
  libappindicator-gtk3,
  pkgs,
  xorg,
  alsa-lib,
  autoPatchelfHook,
  lib,
}:

let
  version = "6.4.3";
  src = fetchzip {
    url = "https://pkg-cdn.jianguoyun.com/static/exe/ex/${version}/nutstore_client-${version}-linux-x86_64-public.tar.gz";
    sha256 = "sha256-jDKzEEoY3nJ0oPybdx8HO1Z7x/eh60KjwlljO2pOYIs=";
    stripRoot = false;
  };
  runtimeLibs = with pkgs; [
    gtk3
    webkitgtk_4_1
    libGL
    libGLU
    glib
    gdk-pixbuf
    pango
    harfbuzz
    at-spi2-core
    cairo
    fontconfig
    freetype
  ];
  ldLibraryPath = lib.makeLibraryPath runtimeLibs;
  preLaunch = pkgs.writeScript "nutstore-prelaunch.py" ''
    #!${python3}/bin/python3
    import glob
    import os
    import shutil
    import stat
    import zipfile

    def ensure_native_from_jar(base_dir: str) -> None:
        lib_dir = os.path.join(base_dir, "lib")
        native_dir = os.path.join(lib_dir, "native")
        jars = sorted(glob.glob(os.path.join(lib_dir, "nutstore_client-*.jar")), reverse=True)
        if not jars:
            return
        jar_path = jars[0]
        os.makedirs(native_dir, exist_ok=True)
        if not os.access(native_dir, os.W_OK):
            return
        try:
            with zipfile.ZipFile(jar_path) as archive:
                for entry in archive.infolist():
                    if entry.is_dir() or not entry.filename.endswith(".so"):
                        continue
                    target_name = os.path.basename(entry.filename)
                    target_path = os.path.join(native_dir, target_name)
                    tmp_path = target_path + ".tmp"
                    with archive.open(entry) as src, open(tmp_path, "wb") as dst:
                        shutil.copyfileobj(src, dst)
                    os.replace(tmp_path, target_path)
                    mode = os.stat(target_path).st_mode
                    os.chmod(target_path, mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)
        except (FileNotFoundError, zipfile.BadZipFile):
            return

        symlink_pairs = [
            ("libswt-pi4-gtk-4964r8.so", "libswt-pi3-gtk-4964r8.so"),
            ("libswt-pi4-gtk.so", "libswt-pi3-gtk-4964r8.so"),
            ("libswt-pi4.so", "libswt-pi3-gtk-4964r8.so"),
        ]
        for target, source in symlink_pairs:
            source_path = os.path.join(native_dir, source)
            target_path = os.path.join(native_dir, target)
            if os.path.exists(source_path) and not os.path.exists(target_path):
                try:
                    os.symlink(source_path, target_path)
                except FileExistsError:
                    pass

    pkg_share = os.environ.get("NUTSTORE_PKG_SHARE")
    if pkg_share:
        ensure_native_from_jar(pkg_share)
    ensure_native_from_jar(os.path.expanduser("~/.nutstore/dist"))
  '';
  native-libs = stdenv.mkDerivation {
    name = "nutstore-native-libs";
    buildInputs = [
      autoPatchelfHook
      pkgs.webkitgtk_4_1
      gtk3
      cairo
      libGLU
    ];
    autoPatchelfIgnoreMissingDeps = [ "libjawt.so" ];
    dontUnpack = true;
    installPhase = ''
      mkdir $out
      cd $out
      jar_file=$(find ${src}/lib -maxdepth 1 -name 'nutstore_client-*.jar' -print -quit)
      if [ -z "$jar_file" ]; then
        echo "nutstore-client: jar file not found under ${src}/lib" >&2
        exit 1
      fi
      cp "$jar_file" .
      ${jdk}/bin/jar xf "$(basename "$jar_file")"
    '';
  };
in

stdenv.mkDerivation rec {
  pname = "nutstore-client";
  inherit version src;
  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [
    wrapGAppsHook3
    gobject-introspection
    libnotify
    libappindicator-gtk3
    pkgs.webkitgtk_4_1

    (python3.withPackages (p: with p; [ pygobject3 ]))

    autoPatchelfHook
    xorg.libXtst
    alsa-lib
  ];
  buildPhase = ''
    substituteInPlace gnome-config/menu/nutstore-menu.desktop \
      --replace-fail '~/.nutstore/dist/bin/nutstore-pydaemon.py' $out/bin/nutstore
    substituteInPlace gnome-config/autostart/nutstore-daemon.desktop \
      --replace-fail '~/.nutstore/dist' $out/share/nutstore
    substituteInPlace bin/nutstore-pydaemon.py \
      --replace-fail "/usr/bin/python3" "${python3}/bin/python3"
    substituteInPlace bin/nutstore-pydaemon.py \
      --replace-fail 'os.execv(os.path.join(tmp_dir, "bin", "runtime_upgrade"), ("runtime_upgrade", tar_file))' \
                     'os.execv("${pkgs.bash}/bin/bash", ("bash", os.path.join(tmp_dir, "bin", "runtime_upgrade"), tar_file))'
    cp ${native-libs}/*.so lib/native
    cd bin
    python -m compileall .
    cd ..
  '';
  installPhase = ''
            mkdir -p $out/{bin,share}
            cp -aR . $out/share/nutstore
            makeWrapper $out/share/nutstore/bin/nutstore-pydaemon.py $out/bin/.nutstore-wrapped \
              --prefix LD_LIBRARY_PATH : ${ldLibraryPath}
            cat > $out/bin/nutstore <<EOF
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    export NUTSTORE_PKG_SHARE="$out/share/nutstore"
    "${preLaunch}"
    exec $out/bin/.nutstore-wrapped "\$@"
    EOF
            chmod +x $out/bin/nutstore
            install -D -m644 gnome-config/menu/nutstore-menu.desktop $out/share/applications/nutstore.desktop
            install -D -m644 app-icon/nutstore.png $out/share/icons/hicolor/512x512/apps/nutstore.png
  '';
}
