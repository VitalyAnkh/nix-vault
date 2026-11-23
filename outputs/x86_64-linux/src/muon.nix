{
  # NOTE: the args not used in this file CAN NOT be removed!
  # because haumea pass argument lazily,
  # and these arguments are used in the functions like `mylib.nixosSystem`, `mylib.colmenaSystem`, etc.
  inputs,
  lib,
  myvars,
  mylib,
  system,
  genSpecialArgs,
  ...
}@args:
let
  name = "muon";
  base-modules = {
    nixos-modules =
      (map mylib.relativeToRoot [
        # common
        "secrets/nixos.nix"
        "modules/nixos/desktop.nix"
        # host specific
        "hosts/${name}"
        # nixos hardening
        "hardening/nixpaks"
      ])
      ++ [
        # As on eva, in both variants: Ghostty, Zed and Warp name Maple Mono NF CN,
        # and tuios and the Starship prompt need its Nerd Font icons.
        { modules.desktop.fonts.enable = true; }
        {
          # muon is shared by many users, so the UU Remote host is available but
          # never started on its own: no `uuremote-native` user unit is
          # registered. Whoever wants it follows
          # modules/nixos/desktop/networking/uu-remote/README.md.
          modules.desktop.uuRemote.installOnly = true;
        }
      ];
    home-modules = map mylib.relativeToRoot [
      "home/hosts/linux/${name}.nix"
    ];
  };

  modules-niri = {
    nixos-modules = [
      {
        modules.desktop.wayland.enable = true;
        modules.secrets.desktop.enable = true;
        modules.secrets.preservation.enable = true;
      }
      { programs.niri.enable = true; }
    ]
    ++ base-modules.nixos-modules;
    home-modules = base-modules.home-modules;
  };
in
{
  nixosConfigurations = {
    "${name}" = mylib.nixosSystem (base-modules // args);
    "${name}-niri" = mylib.nixosSystem (modules-niri // args);
  };

  # generate iso image for hosts with desktop environment
  packages = {
    "${name}" = inputs.self.nixosConfigurations."${name}".config.system.build.images.iso;
    "${name}-niri" = inputs.self.nixosConfigurations."${name}-niri".config.system.build.images.iso;
  };
}
