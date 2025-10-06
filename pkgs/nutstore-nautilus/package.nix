{
  stdenv,
  fetchzip,
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
  version = "6.4.3";
  src = fetchzip {
    url = "https://www.jianguoyun.com/static/exe/installer/nutstore_linux_src_installer.tar.gz";
    sha256 = "sha256-+xjAIATRdG3z3UZaPBn6NBuiXD074SlgSJjKyF1v7ZU=";
  };
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
