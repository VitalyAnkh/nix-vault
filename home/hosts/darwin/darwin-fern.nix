{ config, ... }:
let
  hostName = "fern";
in
{
  imports = [ ../../darwin ];

  modules.editors.emacs.enable = true;

  programs.ssh.settings."github.com".IdentityFile = "${config.home.homeDirectory}/.ssh/${hostName}";
}
