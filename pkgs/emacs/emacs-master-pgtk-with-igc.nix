{
  emacs31-pgtk,
  lib,
  stdenv,
  ccacheStdenv,
  source-emacs-master-igc,
  mps,
  libgccjit,
  ...
}:
let
  source-emacs = source-emacs-master-igc;
in
(emacs31-pgtk.override {
  #stdenv = ccacheStdenv;
  withPgtk = true;
  # toolkit = "lucid";
  # withCairo = false;
  srcRepo = true;
}).overrideAttrs
  (old: rec {
    pname = "emacs-master-pgtk-with-igc";
    # Prefer nvfetcher git `date` when present; webpage-based pins only have `version` (commit).
    name = "${pname}-${
      if source-emacs ? date then
        builtins.concatStringsSep "" (lib.splitString "-" source-emacs.date)
      else
        builtins.substring 0 8 source-emacs.version
    }";
    inherit (source-emacs) src;
    buildInputs = old.buildInputs ++ [
      mps
    ];
    configureFlags = old.configureFlags ++ [
      "--with-mps=yes"
    ];
    patches = [ ];
    postPatch =
      old.postPatch
      + (lib.optionalString ((old ? NATIVE_FULL_AOT) || (old ? env.NATIVE_FULL_AOT)) (
        let
          backendPath = lib.concatStringsSep " " (
            builtins.map (x: ''\"-B${x}\"'') (
              [
                # Paths necessary so the JIT compiler finds its libraries:
                "${lib.getLib libgccjit}/lib"
                "${lib.getLib libgccjit}/lib/gcc"
                "${lib.getLib stdenv.cc.libc}/lib"
              ]
              ++ lib.optionals (stdenv.cc ? cc.libgcc) [
                "${lib.getLib stdenv.cc.cc.libgcc}/lib"
              ]
              ++ [
                # Executable paths necessary for compilation (ld, as):
                "${lib.getBin stdenv.cc.cc}/bin"
                "${lib.getBin stdenv.cc.bintools}/bin"
                "${lib.getBin stdenv.cc.bintools.bintools}/bin"
              ]
            )
          );
        in
        ''
          substituteInPlace lisp/emacs-lisp/comp.el --replace-warn \
                                      "(defcustom comp-libgccjit-reproducer nil" \
                                      "(setq native-comp-driver-options '(${backendPath}))
          (defcustom comp-libgccjit-reproducer nil"
        ''
      ));
  })
