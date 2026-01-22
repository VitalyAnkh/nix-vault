# xremap on muon should only affect the vitalyr user, since this host has multiple users.
# The xremap module and base key mappings are defined in `modules/nixos/base/key-remap.nix`.
{ myvars, ... }:
{
  services.xremap = {
    enable = true;
    serviceMode = "system";
    userName = myvars.username; # "vitalyr"
  };
}
