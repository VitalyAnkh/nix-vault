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

  # Godot master currently uses XR_EXT_spatial_container, which is only present
  # in the OpenXR SDK development branch and not in the latest stable release.
  openxr-loader-main = openxr-loader.overrideAttrs (_old: {
    version = "unstable-2026-09-12";
    src = fetchFromGitHub {
      owner = "KhronosGroup";
      repo = "OpenXR-SDK-Source";
      rev = "2b99fec95e9cdf352c1a98e9cb23bf4def1cf8e6";
      hash = "sha256-LQ27i1hOKt9Zylgw6Wn8cpOF81EVepS6p99ur+CNmyM=";
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
