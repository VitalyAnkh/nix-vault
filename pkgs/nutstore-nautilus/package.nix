{
  stdenv,
  source-nutstore-nautilus,
  autoconf,
  automake,
  libtool,
  pkg-config,
  nautilus,
  glib,
}:
stdenv.mkDerivation {
  pname = "nutstore-nautilus";
  inherit (source-nutstore-nautilus) src version;
  nativeBuildInputs = [
    autoconf
    automake
    libtool
    pkg-config
  ];
  buildInputs = [
    nautilus.dev
    glib
  ];
  # configure requires GDK 2 and ATK, but the extension calls none of their
  # functions: its sources include the GTK headers only for Nautilus 3 and
  # older. Dropping the checks builds it without GTK 2, which nixpkgs marks
  # broken ahead of its removal, and keeps GTK 2's GDK out of Nautilus (GTK 4).
  postPatch = ''
    substituteInPlace configure.ac \
      --replace-fail 'PKG_CHECK_MODULES([GDK], [gdk-2.0 >= $GDK_REQUIRED])' "" \
      --replace-fail 'PKG_CHECK_MODULES([ATK], [atk >= $ATK_REQUIRED])' ""
  '';
  preConfigure = "source ./update-toolchain.sh; set +u";
  configureFlags = [ "--with-nautilus-extension-dir=$(out)/lib/nautilus/extension-4" ];
}
