_args: final: prev: {
  # Keep the repository's pinned package: the current NUR snapshot no longer
  # exports this attribute, while the local package supports both Linux arches.
  computer-use-linux = final.callPackage ../pkgs/computer-use-linux { };
}
