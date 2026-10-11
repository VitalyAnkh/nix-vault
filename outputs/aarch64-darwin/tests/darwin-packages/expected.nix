{
  lib,
  outputs,
}:
lib.genAttrs (builtins.attrNames outputs.darwinConfigurations) (name: {
  nodejsHasV8Fix = true;
  emacsIsNs = true;
  emacsHasAutoloadFix = true;
  androidToolsUseMacArchive = true;
  nodeBuildUsersFromUpstream = {
    zotero = true;
    marksman = true;
    argocdUi = true;
    arrowAzurite = true;
    furo = true;
  };
  jeepneyPrivateBus = false;
  # Only astra replaces the shared OpenLDAP override with the upstream package.
  openldapUsesUpstream = name == "astra";
})
