{
  emacs31,
  emacs31-pgtk,
  lib,
  stdenv,
  ccacheStdenv,
  source-emacs-master-igc,
  ...
}:
let
  source-emacs = source-emacs-master-igc;
  isDarwin = stdenv.hostPlatform.isDarwin;
  baseEmacs = if isDarwin then emacs31 else emacs31-pgtk;
  # No local patches. Of nixpkgs' Emacs patches only the native-comp one is
  # applied: it adds the store paths of libgccjit, binutils and (on Darwin) the
  # SDK to native-comp-driver-options, without which native compilation fails.
  # The IGC source already has the fixes nixpkgs backports to Emacs 31 as CVE
  # patches (master abc802ee and 044b0203), and nothing here uses the
  # Nixpkgs-only early-default library. A patch nixpkgs adds later stops the
  # evaluation until it is listed here.
  appliedPatches = [ "native-comp-driver-options-30.patch" ];
  skippedPatches = [
    "CVE-2024-53920.patch"
    "CVE-2026-108976.patch"
    "load-the-early-default-library-after-early-init.el.patch"
  ];
  patchName = patch: patch.name or (baseNameOf (toString patch));
in
# Keep the historical package attribute for Home Manager and emacs-lsp-booster.
(baseEmacs.override (
  {
    #stdenv = ccacheStdenv;
    srcRepo = true;
    withPgtk = !isDarwin;
    # toolkit = "lucid";
    # withCairo = false;
  }
  // lib.optionalAttrs isDarwin {
    # Spell out the NS feature set instead of relying on nixpkgs' Darwin defaults.
    withNS = true;
    withGTK3 = false;
    withGlibNetworking = false;
    withX = false;
    withNativeCompilation = true;
    withTreeSitter = true;
    withSQLite3 = true;
  }
)).overrideAttrs
  (old: rec {
    pname = if isDarwin then "emacs-master-ns-with-igc" else "emacs-master-pgtk-with-igc";
    # Match AC_INIT in the pinned IGC configure.ac, not the base nixpkgs recipe;
    # postPatch below fails the build when a pin bump changes it.
    version = "32.0.50";
    # Prefer nvfetcher git `date` when present; webpage-based pins only have `version` (commit).
    name = "${pname}-${
      if source-emacs ? date then
        builtins.concatStringsSep "" (lib.splitString "-" source-emacs.date)
      else
        builtins.substring 0 8 source-emacs.version
    }";
    inherit (source-emacs) src;
    patches =
      let
        unknown = lib.subtractLists (appliedPatches ++ skippedPatches) (map patchName old.patches);
      in
      assert lib.assertMsg (
        unknown == [ ]
      ) "emacs: decide whether the IGC source needs nixpkgs' new patches: ${toString unknown}";
      builtins.filter (patch: builtins.elem (patchName patch) appliedPatches) old.patches;
    postPatch = old.postPatch + ''
      grep -qF 'AC_INIT([GNU Emacs], [${version}],' configure.ac || {
        echo "emacs: version ${version} does not match AC_INIT in configure.ac:" >&2
        grep -F 'AC_INIT(' configure.ac >&2
        exit 1
      }
    '';
    # IGC builds the MPS copy bundled in its source tree (mps/); no system libmps is linked.
    configureFlags =
      old.configureFlags
      ++ [ "--with-mps=yes" ]
      ++ lib.optionals isDarwin [
        # Spell out the NS build. Without --without-x, configure's X probe can find
        # XQuartz through /usr/X11 on an unsandboxed builder.
        "--without-pgtk"
        "--without-x"
        "--disable-checking"
      ];
    meta = old.meta // {
      changelog = "https://github.com/emacs-mirror/emacs/blob/${source-emacs.version}/etc/NEWS";
    };
  })
