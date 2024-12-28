{ lib }:
let
  inherit (builtins)
    readDir
    pathExists
    listToAttrs
    ;

  inherit (lib.attrsets)
    filterAttrs
    nameValuePair
    foldlAttrs
    ;

  inherit (lib.strings)
    hasSuffix
    removeSuffix
    ;

  inherit (lib.lists)
    foldl'
    ;
in
{ callPackage
, directory
, packagepredlist ? [ ]
, ...
}:
let
  directoryEntryPred = basename: type:
    type == "directory" && basename != "_sources" ||
    (hasSuffix ".nix" basename && basename != "lib.nix" && basename != "package.nix");

  filterDirectoryEntry = path:
    foldl'
      (attrsets: func: filterAttrs func attrsets)
      (readDir path)
      ([ directoryEntryPred ] ++ packagepredlist);

  packageFromFile = path: basename: type:
    if hasSuffix ".nix" basename
    then
      [
        (nameValuePair
          (removeSuffix ".nix" basename)
          (callPackage (path + "/${basename}") { }))
      ]
    else
      [ ];

  packagesFromDirectoryEntry = path: basename: type:
    let
      defaultPackagePath = path + "/package.nix";
    in
    if pathExists defaultPackagePath
    then
      [
        (nameValuePair
          basename
          (callPackage defaultPackagePath { }))
      ]
    else
      [ ];

  packageFromAttrSets = path: attrsets:
    foldlAttrs
      (acc: basename: type:
        if type == "regular"
        then acc ++ (packageFromFile path basename type)
        else
          if type == "directory"
          then
            (acc ++ (packagesFromDirectoryEntry (path + "/${basename}") basename type)
              ++ (packageFromAttrSets (path + "/${basename}") (filterDirectoryEntry (path + "/${basename}"))))
          else acc
      )
      [ ]
      attrsets;

in
(listToAttrs
  (packageFromAttrSets directory (filterDirectoryEntry directory)))
