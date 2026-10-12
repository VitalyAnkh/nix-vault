_args: final: _prev: {
  # The local prebuilt package is kept in pkgs/ because NUR no longer exports
  # cua-driver for the systems used by this flake.
  cua-driver = final.callPackage ../pkgs/cua-driver { };
}
