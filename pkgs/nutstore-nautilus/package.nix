{
  stdenv,
  source-nutstore-nautilus,
  autoconf,
  automake,
  libtool,
  pkg-config,
  nautilus,
  gtk2,
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
    gtk2
    glib
  ];
  preConfigure = "source ./update-toolchain.sh; set +u";
  configureFlags = [ "--with-nautilus-extension-dir=$(out)/lib/nautilus/extension-4" ];
}
