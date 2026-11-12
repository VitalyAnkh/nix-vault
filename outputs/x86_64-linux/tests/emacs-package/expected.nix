{
  lib,
  outputs,
}:
lib.genAttrs [ "eva" "muon" ] (_: {
  pname = "emacs-master-pgtk-with-igc";
  patches = [ "native-comp-driver-options-30.patch" ];
})
