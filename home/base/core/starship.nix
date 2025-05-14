{
  pkgs,
  nur-ryan4yin,
  ...
}:
{
  programs.starship = {
    enable = true;

    enableBashIntegration = true;
    enableZshIntegration = true;
    enableNushellIntegration = true;

    settings =
      {
        character = {
          success_symbol = "[›](bold green)";
          error_symbol = "[›](bold red)";
        };
        aws = {
          symbol = "🅰 ";
        };
        gcloud = {
          # do not show the account/project's info
          # to avoid the leak of sensitive information when sharing the terminal
          format = "on [$symbol$active(\($region\))]($style) ";
          symbol = "🅶 ️";
        };

        palette = "catppuccin_mocha";
      }
      // builtins.fromTOML (
        builtins.readFile "${nur-ryan4yin.packages.${pkgs.system}.catppuccin-starship}/palettes/mocha.toml"
      );
  };
}
