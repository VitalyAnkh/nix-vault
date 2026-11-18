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
    # Linux keeps the PGTK build of the IGC Emacs.
    inherit (emacs) pname;
    # No local patches; of nixpkgs' patches the native-comp and .dir-locals.el ones.
    patches = map (patch: patch.name or (baseNameOf (toString patch))) emacs.patches;
  }
)
