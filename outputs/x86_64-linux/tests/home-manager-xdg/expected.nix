{ myvars, lib }:
let
  username = myvars.username;
in
lib.genAttrs
  [
    "eva"
    "ruby"
  ]
  (_: {
    enable = true;
    stateHome = "/home/${username}/.local/state";
  })
