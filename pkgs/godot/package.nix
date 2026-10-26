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
    version = "unstable-2026-10-16";
    src = fetchFromGitHub {
      owner = "KhronosGroup";
      repo = "OpenXR-SDK-Source";
      rev = "a9f14c416e383d05c142f5a2539a91fe3931b52a";
      hash = "sha256-NFsbjGgraHnvOHkoDbjRJn0bssT4kjUY0srjEvvdapY=";
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
