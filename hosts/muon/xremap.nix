{ xremap-flake, ... }:
{
  # Import xremap home-manager module
  imports = [
    xremap-flake.homeManagerModules.default
  ];

  # Configure xremap for user service (only for vitalyr user)
  services.xremap = {
    # Run as user service instead of system service
    serviceMode = "user";
    
    config = {
      # Modmap for single key rebinds
      modmap = [
        {
          name = "Global";
          remap = {
            "CapsLock" = "CTRL_L";
          }; # globally remap CapsLock to Ctrl
        }
        {
          name = "Example CTRL_L > CapsLock";
          remap = {
            "CTRL_L" = "CapsLock";
          };
        }
      ];

      # Keymap for key combo rebinds
      keymap = [
        #{
        #  name = "Example ctrl-u > pageup rebind";
        #  remap = { "CapsLock" = "CTRL_L"; };
        # NOTE: no application-specific remaps work without features (see configuration)
        #}
      ];
    };
  };
}