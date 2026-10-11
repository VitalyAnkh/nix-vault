{
  lib,
  outputs,
}:
lib.genAttrs [ "eva" "muon" ] (
  name:
  let
    emacs = outputs.nixosConfigurations.${name}.pkgs.emacs-master-pgtk-with-igc;
  in
  {
    # Linux keeps the PGTK build of the IGC Emacs, with the bug#81906 backport.
    inherit (emacs) pname;
    hasAutoloadFix = builtins.any (
      patch: lib.hasSuffix "/make-autoload-arglist.patch" (toString patch)
    ) emacs.patches;
  }
)
