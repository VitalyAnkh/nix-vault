{ myvars, lib }:
let
  username = myvars.username;
in
lib.genAttrs
  [
    "eva"
    "aquamarine"
    "ruby"
  ]
  (_: {
    enable = true;
    stateHome = "/home/${username}/.local/state";
  })
