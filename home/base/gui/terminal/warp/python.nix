# The Python that runs the Warp settings sync and its tests. tomli reads TOML 1.1, which
# Warp writes; `just warp-test` builds this file with the flake's nixpkgs.
{ python3 }: python3.withPackages (ps: [ ps.tomli ])
