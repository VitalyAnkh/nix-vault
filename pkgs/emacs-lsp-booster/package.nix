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

  # cargoHash = "sha256-7AQAe3uTLXY44nk/RSucCpxdvOjxvk4z8UaFDa6Pcs0=";
  cargoHash = "sha256-qchwxW3KITQcv6EFzR2BSISWB2aTW9EdCN/bx5m0l48=";

  nativeCheckInputs = [ pkgs.emacs-master-pgtk-with-igc ]; # tests/bytecode_test

  meta = with lib; {
    description = "Emacs LSP performance booster";
    homepage = "https://github.com/blahgeek/emacs-lsp-booster";
    license = licenses.mit;
    mainProgram = "emacs-lsp-booster";
  };
}
