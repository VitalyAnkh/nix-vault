{
  myvars,
  lib,
  outputs,
}:
let
  username = myvars.username;
  hosts = [
    "fern"
    "frieren"
  ];
in
lib.genAttrs hosts (
  name:
  let
    home = outputs.darwinConfigurations.${name}.config.home-manager.users.${username};
    # mkOutOfStoreSymlink builds its link with `ln -s <target> $out`.
    linkTarget =
      file:
      builtins.head (
        builtins.match "ln -s '?([^']+)'? [$]out[[:space:]]*" home.home.file.${file}.source.buildCommand
      );
  in
  {
    inherit (home.home) homeDirectory;
    # The `j` alias and the proxychains link use the checkout.
    justAlias = home.home.shellAliases.j;
    proxychainsConfig = linkTarget ".proxychains/proxychains.conf";
  }
)
