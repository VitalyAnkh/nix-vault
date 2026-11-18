{
  lib,
  outputs,
}:
lib.genAttrs (builtins.attrNames outputs.darwinConfigurations) (_: {
  nodejsUsesUpstream = true;
  emacsIsNs = true;
  emacsPatches = [
    "fix-arbitrary-code-execution-in-dot-dir-locals-dot-el-handling.patch"
    "fix-regression-after--fix-arbitrary-code-execution-in-dot-dir-locals-dot-el-handling.patch"
    "native-comp-driver-options-30.patch"
  ];
  androidToolsUseMacArchive = true;
  androidToolsAtLeastUpstream = true;
  jetbrainsToolboxAtLeastUpstream = true;
  fromUpstreamCache = {
    zotero = true;
    marksman = true;
    argocdUi = true;
    arrowAzurite = true;
    furo = true;
  };
  jeepneyPrivateBus = false;
  # No shared override replaces nixpkgs' OpenLDAP any more.
  openldapUsesUpstream = true;
})
