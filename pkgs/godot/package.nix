{
  godot,
  lib,
  source-godot-master,
  ...
}:

let
  rev = source-godot-master.version;
  shortRev = builtins.substring 0 7 rev;
in
godot.overrideAttrs (old: {
  version = "master-${shortRev}";
  src = source-godot-master.src;

  postPatch = (old.postPatch or "") + ''
    rm -rf .git
    mkdir .git
    echo ${lib.escapeShellArg rev} > .git/HEAD
  '';

  meta = (old.meta or { }) // {
    description = "Godot Engine editor built from the official development branch";
    sourceProvenance = [ lib.sourceTypes.fromSource ];
  };
})
