{
  lib,
  rustPlatform,
  source-emacs-lsp-booster,
  pkgs,
  ...
}:
rustPlatform.buildRustPackage rec {
  pname = "emacs-lsp-booster";
  version = "0.2.1";

  inherit (source-emacs-lsp-booster) src;

  cargoHash = "sha256-CvIJ56QrIzQULFeXYQXTpX9PoGx1/DWtgwzfJ+mljEI=";

  nativeCheckInputs = [pkgs.emacs-master-igc-pgtk]; # tests/bytecode_test

  meta = with lib; {
    description = "Emacs LSP performance booster";
    homepage = "https://github.com/blahgeek/emacs-lsp-booster";
    license = licenses.mit;
    mainProgram = "emacs-lsp-booster";
  };
}
