{
  pkgs,
  daeuniverse,
  ...
}: {
  imports = [
    daeuniverse.nixosModules.dae
    daeuniverse.nixosModules.daed
    /*
    This is effectively an inline module
    */
    {
      services.daed = {
        enable = true;

        openFirewall = {
          enable = true;
          port = 12345;
        };

        package = daeuniverse.packages.x86_64-linux.daed;
        configDir = "/etc/daed";
        listen = "127.0.0.1:2023";
      };
    }
  ];
}
