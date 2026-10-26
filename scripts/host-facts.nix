# Facts about one host that a merge must not change by accident: boot, storage,
# networking, secrets, services, packages and the users' Home Manager files.
# scripts/host-diff.py evaluates this for two revisions and prints what differs.
{ flake, host }:
let
  f = builtins.getFlake flake;
  inherit (f.inputs.nixpkgs) lib;
  isNixos = f.nixosConfigurations ? ${host};
  c = if isNixos then f.nixosConfigurations.${host}.config else f.darwinConfigurations.${host}.config;

  names =
    ps: lib.sort lib.lessThan (lib.unique (map (p: if p ? pname then p.pname else lib.getName p) ps));
  enabledUnits =
    units: lib.sort lib.lessThan (lib.attrNames (lib.filterAttrs (_: u: u.enable) units));
  enabledFiles =
    files: lib.sort lib.lessThan (lib.attrNames (lib.filterAttrs (_: v: v.enable) files));
  hmUsers = lib.attrNames (c.home-manager.users or { });

  common = {
    secrets = builtins.mapAttrs (_: s: {
      file = toString s.file;
      inherit (s)
        mode
        owner
        group
        path
        ;
    }) (c.age.secrets or { });
    agenixEtc = enabledFiles (lib.filterAttrs (n: _: lib.hasPrefix "agenix/" n) c.environment.etc);
    environmentVariables = c.environment.variables;
    systemPackages = names c.environment.systemPackages;
    home = lib.genAttrs hmUsers (
      u:
      let
        hm = c.home-manager.users.${u};
      in
      {
        files = enabledFiles hm.home.file;
        packages = names hm.home.packages;
        sessionVariables = hm.home.sessionVariables;
        userServices = lib.attrNames (hm.systemd.user.services or { });
        inputMethod = {
          type = hm.i18n.inputMethod.type or null;
          addons = names (hm.i18n.inputMethod.fcitx5.addons or [ ]);
        };
        emacs = hm.programs.emacs.package.name or null;
      }
    );
  };

  nixos = {
    fileSystems = builtins.mapAttrs (_: v: {
      inherit (v)
        device
        fsType
        options
        neededForBoot
        ;
    }) c.fileSystems;
    swapDevices = map (s: {
      inherit (s) device;
      size = s.size or null;
    }) c.swapDevices;
    zram = c.zramSwap.enable;
    zswap = c.boot.zswap.enable or null;
    boot = {
      systemdBoot = c.boot.loader.systemd-boot.enable;
      grub = c.boot.loader.grub.enable;
      efiMount = c.boot.loader.efi.efiSysMountPoint;
      canTouchEfi = c.boot.loader.efi.canTouchEfiVariables;
      timeout = c.boot.loader.timeout;
      kernel = c.boot.kernelPackages.kernel.version;
      kernelParams = c.boot.kernelParams;
      kernelModules = c.boot.kernelModules;
      blacklisted = c.boot.blacklistedKernelModules;
      initrdAvailable = c.boot.initrd.availableKernelModules;
      initrdModules = c.boot.initrd.kernelModules;
      # nixpkgs removed the option once the systemd initrd became the only one;
      # reading the removed option throws.
      initrdSystemd =
        let
          r = builtins.tryEval c.boot.initrd.systemd.enable;
        in
        if r.success then r.value else true;
      luks = lib.attrNames c.boot.initrd.luks.devices;
      resumeDevice = c.boot.resumeDevice;
      sysctl = c.boot.kernel.sysctl;
    };
    disko =
      if c ? disko then
        {
          inherit (c.disko) enableConfig;
          disks = lib.attrNames (c.disko.devices.disk or { });
        }
      else
        null;
    preservation = if c ? preservation then c.preservation.preserveAt else null;
    networking = {
      inherit (c.networking) hostName useNetworkd useDHCP;
      networkmanager = c.networking.networkmanager.enable;
      networkmanagerUnmanaged = c.networking.networkmanager.unmanaged;
      networkd = c.systemd.network.enable;
      resolved = c.services.resolved.enable;
      dhcpcd = c.networking.dhcpcd.enable;
      firewall = c.networking.firewall.enable;
      nameservers = c.networking.nameservers;
    };
    users = lib.genAttrs hmUsers (u: lib.sort lib.lessThan (c.users.users.${u}.extraGroups or [ ]));
    systemServices = enabledUnits c.systemd.services;
    userServices = enabledUnits c.systemd.user.services;
    stateVersion = c.system.stateVersion;
  };

  darwin = {
    brews = map (b: b.name or b) c.homebrew.brews;
    casks = map (b: b.name or b) c.homebrew.casks;
    launchdDaemons = lib.attrNames c.launchd.daemons;
    launchdAgents = lib.attrNames c.launchd.user.agents;
    stateVersion = c.system.stateVersion;
  };
in
common // (if isNixos then nixos else darwin)
