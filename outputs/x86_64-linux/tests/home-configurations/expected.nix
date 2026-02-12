{
  lib,
  myvars,
}:
let
  username = myvars.username;
  hosts = [
    "revachol"
    "jojo"
  ];
in
lib.genAttrs hosts (_: {
  inherit username;
  homeDirectory = "/home/${username}";
  actualUsername = username;
})
