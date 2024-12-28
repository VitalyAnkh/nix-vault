{ emacs30
, lib
, ccacheStdenv
, source-emacs-master-igc
, mps
, ...
}:
(emacs30.override { stdenv = ccacheStdenv; withPgtk = true; }).overrideAttrs (
  old: {
    pname = "emacs-master-igc-pgtk";
    name = "emacs-master-igc-pgtk-${builtins.concatStringsSep "" (lib.splitString "-" source-emacs-master-igc.date)}";
    inherit (source-emacs-master-igc) src;
    buildInputs = old.buildInputs ++ [ mps ];
    configureFlags = old.configureFlags ++ [ "--with-mps=yes" ];
  }
)
