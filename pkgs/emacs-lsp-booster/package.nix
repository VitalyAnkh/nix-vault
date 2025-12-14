{
  lib,
  rustPlatform,
  source-emacs-lsp-booster,
  pkgs,
  ...
}:
rustPlatform.buildRustPackage {
  pname = "emacs-lsp-booster";
  version = "0.2.1";

  inherit (source-emacs-lsp-booster) src;

  cargoHash = "sha256-7lIceMT2hJplHU2VIN1O8IiGE6+DxO4/uM8pYS/qvlE=";

  nativeCheckInputs = [ pkgs.emacs-master-pgtk-with-igc ]; # tests/bytecode_test

  meta = with lib; {
    description = "Emacs LSP performance booster";
    homepage = "https://github.com/blahgeek/emacs-lsp-booster";
    license = licenses.mit;
    mainProgram = "emacs-lsp-booster";
  };
}
