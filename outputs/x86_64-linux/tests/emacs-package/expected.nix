{
  lib,
  outputs,
}:
lib.genAttrs [ "eva" "muon" ] (_: {
  pname = "emacs-master-pgtk-with-igc";
  hasAutoloadFix = true;
})
