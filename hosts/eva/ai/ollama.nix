{
  pkgs,
  ...
}:
let
  ollamaHome = "/var/lib/ollama";
in
{
  services.ollama = rec {
    enable = true;
    package = pkgs.ollama-cuda;
    host = "0.0.0.0";
    port = 11434;
    home = ollamaHome;
    modelsDir = "${home}/models";
  };
}
