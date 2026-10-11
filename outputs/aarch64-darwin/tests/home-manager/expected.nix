{
  myvars,
  lib,
}:
let
  username = myvars.username;
  hosts = [
    "fern"
    "frieren"
  ];
  checkout = "/Users/${username}/nix-vault";
in
lib.genAttrs hosts (_: {
  homeDirectory = "/Users/${username}";
  justAlias = "just -f ${checkout}/justfile";
  aerospaceConfig = "${checkout}/home/darwin/aerospace/aerospace.toml";
  proxychainsConfig = "${checkout}/home/darwin/proxy/proxychains.conf";
})
