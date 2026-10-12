{
  myvars,
  outputs,
  ...
}:
let
  cfg = outputs.nixosConfigurations."eva-niri".config;
  hm = cfg.home-manager.users.${myvars.username};
  packageNames = map (package: package.pname or "") hm.i18n.inputMethod.fcitx5.addons;
in
{
  enablesLocalAsr = builtins.elem "fcitx5-vinput" packageNames;
  enablesLitePackage = builtins.elem "fcitx5-vinput-lite" packageNames;
  hasVinputDaemon = hm.systemd.user.services ? vinput-daemon;
  usesCustomRime = builtins.any (name: name == "fcitx5-rime") packageNames;
}
