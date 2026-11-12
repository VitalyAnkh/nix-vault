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
    # No local patches; of nixpkgs' patches only the native-comp one.
    patches = map (patch: patch.name or (baseNameOf (toString patch))) emacs.patches;
  }
)
