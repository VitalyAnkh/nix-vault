{
  config,
  lib,
  pkgs,
  nixpkgsConfig,
  ...
}:
let
  hasNixAccessTokensSecret =
    config ? age && builtins.hasAttr "nix-access-tokens" (config.age.secrets or { });
in
{
  # Nix 2.35 is newer than nixpkgs' nixVersions.stable (still 2.34), so opt into
  # the latest released version until stable catches up.
  # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/tools/package-management/nix/default.nix
  nix.package = pkgs.nixVersions.latest;
  warnings = lib.optional (lib.versionAtLeast pkgs.nixVersions.stable.version "2.35") "nixVersions.stable is 2.35+: drop the nixVersions.latest override (WA-023)";

  # https://lix.systems/add-to-config/
  # nix.package = pkgs.lix;

  # The flake's Nixpkgs policy (outputs/default.nix): unfree packages, the permitted
  # insecure Firefox ESR, and the npm mirror for fetches inside builds. Upstream sets
  # it in modules/base/nix.nix; nix-darwin rejects nixpkgs.config next to the
  # nixpkgs.pkgs instance lib/macosSystem.nix creates from the same set.
  nixpkgs.config = nixpkgsConfig;

  # do garbage collection weekly to keep disk usage low
  nix.gc = {
    automatic = lib.mkDefault true;
    dates = lib.mkDefault "weekly";
    options = lib.mkDefault "--delete-older-than 7d";
  };

  # Manual optimise storage: nix-store --optimise
  # https://nixos.org/manual/nix/stable/command-ref/conf-file.html#conf-auto-optimise-store
  nix.settings = {
    auto-optimise-store = true;

    # Required to run nixpkgs' systemd-nspawn based NixOS tests locally (used
    # by the nixpkgs-review workflow). These are daemon-wide settings, so every
    # local build pays the small uid/cgroup allocation overhead; drop them if
    # you stop running those tests.
    # Reference: https://github.com/NixOS/nixpkgs/pull/478109
    auto-allocate-uids = true;
    extra-system-features = [ "uid-range" ];
    experimental-features = [
      "auto-allocate-uids"
      "cgroups"
    ];
    # Use extra-sandbox-paths instead of sandbox-paths here. The plain
    # sandbox-paths setting replaces Nix's compiled sandbox defaults, including
    # the sandbox shell that provides /bin/sh for builders with legacy shebangs.
    # extra-sandbox-paths keeps those defaults and only adds the paths we need.
    # After deploying, verify the effective daemon config with:
    #   nix config show | grep sandbox-paths
    extra-sandbox-paths = [
      "/dev/net"
    ];
  };

  nix.channel.enable = false; # remove nix-channel related tools & configs, we use flakes instead.

  nix.extraOptions = lib.optionalString hasNixAccessTokensSecret ''
    !include ${config.age.secrets."nix-access-tokens".path}
  '';
}
