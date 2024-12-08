{pkgs, xremap-flake, ...}: {
  # Use xremap to swap Ctrl and CapsLock 
  imports = [      
        xremap-flake.nixosModules.default
        /* This is effectively an inline module */
        {

          # Modmap for single key rebinds
          services.xremap.config.modmap = [
            {
              name = "Global";
              remap = { "CapsLock" = "CTRL_L"; }; # globally remap CapsLock to Ctrl
            }
	    {
              name = "Example CTRL_L > CapsLock";
              remap = { "CTRL_L" = "CapsLock"; };
            }
          ];

          # Keymap for key combo rebinds
          services.xremap.config.keymap = [
            #{
            #  name = "Example ctrl-u > pageup rebind";
            #  remap = { "CapsLock" = "CTRL_L"; };
              # NOTE: no application-specific remaps work without features (see configuration)
            #}
          ];
        }
   ];
}
