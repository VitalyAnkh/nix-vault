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
    # nixpkgs' patches and postPatch apply to the IGC pin; its native-comp patch
    # adds the toolchain and SDK paths to Emacs' own driver options.
    patches =
      # The IGC source already has the flymake trust check that nixpkgs backports to
      # Emacs 30 and 31 as CVE-2024-53920.patch, which therefore no longer applies.
      builtins.filter (patch: !lib.hasSuffix "-CVE-2024-53920.patch" (toString patch)) old.patches
      ++ [
        # The IGC branch lacks master's fix for bug#81906 (commit 008a667120): the
        # obsolete `make-autoload`, which Doom uses to generate autoloads, fails on
        # every autoload cookie. Drop it once the pin includes that commit.
        ./make-autoload-arglist.patch
      ]
      ++ lib.optionals isDarwin [
        # Local patch, written against IGC's `struct frame **emacsframe`: answer
        # AXValue/AXSelectedText from the queried window's own buffer via
        # make_buffer_string, where the pinned nsterm.m uses the selected frame and
        # copies raw bytes across the buffer gap. Drop it once upstream fixes this.
        ./ns-accessibility-buffer-text.patch
      ];
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
