{
  lib,
  outputs,
  myvars,
}:
lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (
  name:
  {
    # Neither password nor PAM keyboard-interactive login is offered, except that
    # eva and muon keep password login on purpose (hosts/{eva,muon}/default.nix).
    PasswordAuthentication = builtins.elem name [
      "eva"
      "eva-niri"
      "muon"
      "muon-niri"
    ];
    KbdInteractiveAuthentication = false;
    # Undeclared keys in ~/.ssh/authorized_keys are not honoured.
    authorizedKeysInHomedir = false;
    # Only the interactive admin keys open a root shell; remote-builder host keys
    # are pinned to the nix-daemon protocol, served by the system daemon.
    unrestrictedRootKeys = builtins.length (
      myvars.mainSshAuthorizedKeys ++ myvars.secondaryAuthorizedKeys
    );
  }
  // lib.optionalAttrs (name == "aquamarine") {
    builderKeys = map (
      key: ''restrict,command="nix-daemon --stdio --store daemon" ${key}''
    ) myvars.remoteBuilderClientKeys;
  }
)
