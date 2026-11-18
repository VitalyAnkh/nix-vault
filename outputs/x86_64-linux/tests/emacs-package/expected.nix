{
  lib,
  outputs,
}:
lib.genAttrs [ "eva" "muon" ] (_: {
  pname = "emacs-master-pgtk-with-igc";
  patches = [
    "fix-arbitrary-code-execution-in-dot-dir-locals-dot-el-handling.patch"
    "fix-regression-after--fix-arbitrary-code-execution-in-dot-dir-locals-dot-el-handling.patch"
    "native-comp-driver-options-30.patch"
  ];
})
