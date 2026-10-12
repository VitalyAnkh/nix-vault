{
  fetchFromGitHub,
  godot,
  lib,
  openxr-loader,
  source-godot-master,
  ...
}:

let
  rev = source-godot-master.version;
  shortRev = builtins.substring 0 7 rev;

  # Godot master bundles OpenXR 1.1.63 and uses XR_EXT_spatial_container, while
  # nixpkgs' openxr-loader is still 1.1.62. Build the loader from OpenXR-SDK-Source main.
  openxr-loader-main = openxr-loader.overrideAttrs (_old: {
    version = "unstable-2026-09-17";
    src = fetchFromGitHub {
      owner = "KhronosGroup";
      repo = "OpenXR-SDK-Source";
      rev = "3ed64d0f9bb680f24b80a085091e5c8fab38f7b7";
      hash = "sha256-eUZEultLvLpm/ycVpYxwjibs1dK3qrF8KricIIxz9OE=";
    };
  });
in
godot.overrideAttrs (old: {
  version = "master-${shortRev}";
  src = source-godot-master.src;

  buildInputs = map (
    input: if (input.pname or "") == "openxr-loader" then openxr-loader-main else input
  ) (old.buildInputs or [ ]);

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
