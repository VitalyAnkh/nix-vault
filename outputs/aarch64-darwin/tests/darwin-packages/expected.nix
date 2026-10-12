{
  lib,
  outputs,
}:
lib.genAttrs (builtins.attrNames outputs.darwinConfigurations) (_: {
  nodejsHasV8Fix = true;
  emacsIsNs = true;
  emacsHasAutoloadFix = true;
  androidToolsUseMacArchive = true;
  androidToolsAtLeastUpstream = true;
  jetbrainsToolboxAtLeastUpstream = true;
  nodeBuildUsersFromUpstream = {
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
