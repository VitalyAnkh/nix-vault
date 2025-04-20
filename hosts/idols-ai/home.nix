{config, ...}: {
  modules.desktop = {
    hyprland = {
      nvidia = true;
      settings.source = [
        "${config.home.homeDirectory}/nix-config/hosts/idols-ai/hypr-hardware.conf"
      ];
    };
  };
  modules.editors.emacs = {
    enable = true;
  };

  programs.ssh.matchBlocks."github.com".identityFile = "${config.home.homeDirectory}/.ssh/idols-ai";
}
