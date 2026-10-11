{
  lib,
  outputs,
}:
lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (
  name:
  let
    settings = outputs.nixosConfigurations.${name}.config.nix.settings;
    effectiveSystemFeatures =
      (settings.system-features or [ ]) ++ (settings.extra-system-features or [ ]);
  in
  {
    autoAllocateUids = settings.auto-allocate-uids or false;
    hasUidRange = builtins.elem "uid-range" effectiveSystemFeatures;
    hasAutoAllocateUidsFeature = builtins.elem "auto-allocate-uids" (
      settings.experimental-features or [ ]
    );
    hasCgroupsFeature = builtins.elem "cgroups" (settings.experimental-features or [ ]);
    hasNoExplicitSandboxPaths = !(settings ? sandbox-paths);
    hasDevNetExtraSandboxPath = builtins.elem "/dev/net" (settings.extra-sandbox-paths or [ ]);
    # Each cache appears once, compared without `?priority=` or a trailing slash:
    # NixOS adds https://cache.nixos.org/ and its key itself.
    substitutersUnique = lib.allUnique (
      map (
        substituter: lib.removeSuffix "/" (builtins.head (lib.splitString "?" substituter))
      ) settings.substituters
    );
    trustsCacheNixosOrg = builtins.elem "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" settings.trusted-public-keys;
  }
)
