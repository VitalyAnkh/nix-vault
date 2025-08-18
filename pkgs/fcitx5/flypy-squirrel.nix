{ stdenv, ... }:
stdenv.mkDerivation {
  pname = "flypy-squirrel";
  version = "1.0.0";

  src = ./rime-data-flypy;

  installPhase = ''
    mkdir -p $out
    cp -r . $out/
  '';

  meta = {
    description = "Flypy input method data for Squirrel";
  };
}
