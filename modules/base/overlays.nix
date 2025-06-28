{ nuenv, mylib, ... }@args:
{
  nixpkgs.overlays = [
    nuenv.overlays.default
    # nix-vault/modules/overlays has been deleted
    # use nix-vault/modules/pkgs
    (
      final: prev:
      let
        sources = prev.callPackage ../../pkgs/_sources/generated.nix { };
      in
      mylib.callPackageFromDirectory {
        callPackage = prev.lib.callPackageWith (prev // sources);
        directory = ../../pkgs;
      }
    )
  ];
}
