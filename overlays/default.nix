args:
# Import every overlay in this directory except the entrypoint and documentation.
builtins.map (f: import (./. + "/${f}") args) (
  builtins.filter (f: f != "default.nix" && f != "README.md") (
    builtins.attrNames (builtins.readDir ./.)
  )
)
