{
  lib,
  rustPlatform,
  source-emacs-lsp-booster,
  emacs-master-pgtk-with-igc,
  ...
}:
rustPlatform.buildRustPackage {
  pname = "emacs-lsp-booster";
  version = "0.2.1";

  inherit (source-emacs-lsp-booster) src;

  cargoLock = source-emacs-lsp-booster.cargoLock."Cargo.lock";

  patches = [
    ./skip-bytecode-stress-tests.patch
  ];

  nativeCheckInputs = [ emacs-master-pgtk-with-igc ]; # tests/bytecode_test

  meta = with lib; {
    description = "Emacs LSP performance booster";
    homepage = "https://github.com/blahgeek/emacs-lsp-booster";
    license = licenses.mit;
    mainProgram = "emacs-lsp-booster";
  };
}
