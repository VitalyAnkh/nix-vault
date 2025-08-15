# This file configures xremap settings for the vitalyr user only
# The xremap module is already imported by key-remap.nix
{ pkgs, myvars, ... }:
{
  # Configure xremap as a system service with user restriction
  services.xremap = {
    # Specify the user under which the service runs
    userName = myvars.username; # This will be "vitalyr"

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
