{
  programs.gh.enable = true;
  programs.git.enable = true;

  programs.zellij.enable = true;
  programs.bash.enable = true;
  programs.nushell.enable = true;

  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableNushellIntegration = true;
  };
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    withPython3 = false;
    withRuby = false;
  };

  home.stateVersion = "26.05";
}
