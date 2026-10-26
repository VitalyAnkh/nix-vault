{
  # haumea passes these arguments lazily to the system constructor.
  inputs,
  lib,
  mylib,
  myvars,
  system,
  genSpecialArgs,
  ...
}@args:
let
  # The account name lives in the private mysecrets input, so this public
  # repository does not name it.
  inherit (import "${inputs.mysecrets}/hosts/astra/account.nix") username;
  hostVars = myvars // {
    inherit username;
    repoRoot = "/Users/${username}/projects/dev/nix/nix-vault";
  };
in
{
  darwinConfigurations.astra = mylib.macosSystem (
    args
    // {
      myvars = hostVars;
      specialArgs = (genSpecialArgs system) // {
        myvars = hostVars;
      };
      darwin-modules = map mylib.relativeToRoot [
        "modules/base/nix.nix"
        "modules/base/packages.nix"
        "modules/base/overlays.nix"
        "modules/base/fonts.nix"
        "modules/darwin/nix-daemon.nix"
        "modules/darwin/system-paths.nix"
        "modules/darwin/users.nix"
        "hosts/darwin-astra"
      ];
      home-modules = map mylib.relativeToRoot [
        "home/hosts/darwin/darwin-astra.nix"
      ];
    }
  );
}
