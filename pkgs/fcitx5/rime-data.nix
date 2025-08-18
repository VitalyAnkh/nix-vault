{ stdenv, ... }:
stdenv.mkDerivation {
  pname = "rime-data";
  version = "1.0.0";

  src = ./rime-data-flypy;

  installPhase = ''
    mkdir -p $out
    cp -r . $out/
  '';

  meta = {
    description = "RIME input method data";
  };
}
