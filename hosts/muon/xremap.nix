# xremap on muon should only affect the vitalyr user, since this host has multiple users.
# The xremap module and base key mappings are defined in `modules/nixos/base/key-remap.nix`.
{ myvars, ... }:
{
  services.xremap = {
    enable = true;
    serviceMode = "user";
    userName = myvars.username; # "vitalyr"
  };

  # Prevent other users' `systemd --user` from starting xremap automatically.
  systemd.user.services.xremap.unitConfig.ConditionUser = myvars.username;
}
