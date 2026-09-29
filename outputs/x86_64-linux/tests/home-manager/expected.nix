{
  myvars,
  lib,
}:
let
  username = myvars.username;
  hosts = [
    "eva"
    "muon"
    "ruby"
  ];
in
lib.genAttrs hosts (_: "/home/${username}")
