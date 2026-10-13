{
  lib,
  myvars,
  outputs,
  ...
}:
let
  check =
    name:
    let
      cfg = outputs.nixosConfigurations.${name}.config;
      hm = cfg.home-manager.users.${myvars.username};
      warp = hm.modules.desktop.warp;
      sync = hm.home.activation.syncWarpSettings;
      preservedDirectories = map (d: if builtins.isString d then d else d.directory) (
        cfg.preservation.preserveAt."/persistent".users.${myvars.username}.directories
      );
    in
    {
      inherit (warp) enable settings;
      settingsFile = lib.removePrefix hm.home.homeDirectory warp.settingsFile;
      # The settings directory survives the tmpfs root, so the merged file does too.
      # Preservation stores user directories as absolute paths.
      preserved = builtins.any (
        directory:
        builtins.elem directory [
          ".config/warp-oss"
          "${hm.home.homeDirectory}/.config/warp-oss"
        ]
      ) preservedDirectories;
      # Warp rewrites its settings file, so it is not a read-only Home Manager link.
      managesMutableConfig = builtins.any (file: lib.hasInfix "warp-oss" file.target) (
        builtins.attrValues hm.home.file
      );
      syncAfterWriteBoundary = builtins.elem "writeBoundary" sync.after;
      syncFailureIsWarning = lib.hasInfix "|| warnEcho" sync.data;
      # The open-source build from pkgs/warp-terminal reads this settings file.
      warpInstalled = builtins.any (
        package: (package.meta.mainProgram or "") == "warp-oss"
      ) cfg.environment.systemPackages;
      # Warp has no fallback font, so the Nerd Font it names must be installed.
      fontInstalled = builtins.any (
        font: lib.hasPrefix "MapleMono-NF-CN" (lib.getName font)
      ) cfg.fonts.packages;
    };
in
{
  eva = check "eva";
  muon = check "muon";
}
