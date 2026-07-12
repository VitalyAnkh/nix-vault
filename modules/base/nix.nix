{
  pkgs,
  config,
  myvars,
  ...
}:
{
  nix.settings = {
    # enable flakes globally
    experimental-features = [
      "nix-command"
      "flakes"
    ];

    # given the users in this list the right to specify additional substituters via:
    #    1. `nixConfig.substituers` in `flake.nix`
    #    2. command line args `--options substituers http://xxx`
    trusted-users = [ myvars.username ];

    # Substituters in priority order (most reliable first). Putting mirrors first can lead to noisy
    # `error: file 'nar/…' does not exist in binary cache ...` messages when a mirror lags behind.
    substituters = [
      # official cache
      "https://cache.nixos.org"

      # community cache
      "https://nix-community.cachix.org"
      "https://catppuccin.cachix.org"

      # cache mirrors located in China (fallback)
      "https://mirrors.sustech.edu.cn/nix-channels/store"
      "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
      "https://mirrors.ustc.edu.cn/nix-channels/store"
    ];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "catppuccin.cachix.org-1:noG/4HkbhJb+lUAdKrph6LaozJvAeEEZj4N732IysmU="
    ];
    builders-use-substitutes = true;
  };
}
