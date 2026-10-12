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
    #
    # Upstream (#335) no longer trusts the normal user: a trusted user can add
    # substituters, a known root-equivalent path through the daemon. Kept here:
    # the user decided so in the 2026-10 merge (docs/upstream-sync.md).
    trusted-users = [ myvars.username ];

    # WARNING: `substituters` + `trusted-public-keys` are a security boundary,
    # not a convenience list. Nix downloads prebuilt store paths from a
    # substituter, and a trusted key means "trust anything signed by it" —
    # together they let a cache inject arbitrary store paths into your system,
    # which are then run as root at activation. Only add caches you fully trust.
    #
    # Nix queries substituters in priority order, lowest value first. Each cache
    # advertises a priority in its nix-cache-info; `?priority=` overrides it. NixOS and
    # nix-darwin add https://cache.nixos.org/ (priority 40) and its key themselves.
    substituters = [
      # community caches (priority 41)
      "https://nix-community.cachix.org"
      "https://catppuccin.cachix.org"
      # llm-agents.nix (grok, wrap-buddy, and other agent CLIs). It advertises priority 30
      # but serves only these packages, so query it after the general caches.
      "https://cache.numtide.com?priority=42"

      # cache mirrors located in China, as a fallback. Querying mirrors before
      # cache.nixos.org leads to noisy `error: file 'nar/…' does not exist in binary
      # cache ...` messages when a mirror lags behind.
      "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store?priority=50"
      "https://mirrors.ustc.edu.cn/nix-channels/store?priority=50"
    ];

    # WARNING: every key here trusts *everything* that key signs. Add one only
    # for a cache you trust as much as the official one — a careless key hands
    # a third party the ability to ship you arbitrary store paths.
    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "catppuccin.cachix.org-1:noG/4HkbhJb+lUAdKrph6LaozJvAeEEZj4N732IysmU="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
    builders-use-substitutes = true;
  };
}
