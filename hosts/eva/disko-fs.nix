# Declarative layout of eva's system disk, after upstream ai's disko-fs.nix.
#
# Only for a reinstall: default.nix sets `disko.enableConfig = false`, so the
# running system keeps the mounts from hardware-configuration.nix and this file
# changes nothing on activation. It mirrors the disk as installed: the GPT
# labels ESP and primary, a 1950 MiB ESP, one unencrypted btrfs with these
# subvolumes and mount options, and the 64 GiB swapfile on @swap. There is no
# LUKS layer and no data disk, unlike upstream's ai.
#
#   nix run github:nix-community/disko -- --mode mount hosts/eva/disko-fs.nix
#
# `--mode destroy,format,mount` wipes the disk.
{
  disko.devices = {
    nodev."/" = {
      fsType = "tmpfs";
      mountOptions = [
        "relatime"
        "mode=755"
      ];
    };

    disk.eva = {
      type = "disk";
      device = "/dev/disk/by-id/nvme-CT2000T700SSD3_2417E8AB7D30";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            priority = 1;
            label = "ESP";
            size = "1950M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [
                "fmask=0022"
                "dmask=0022"
              ];
            };
          };
          primary = {
            label = "primary";
            size = "100%";
            content = {
              type = "btrfs";
              subvolumes = {
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = [
                    "compress-force=zstd:5"
                    "noatime"
                  ];
                };
                "@guix".mountpoint = "/gnu";
                "@tmp".mountpoint = "/tmp";
                "@swap" = {
                  mountpoint = "/swap";
                  swap.swapfile.size = "64G";
                };
                "@persistent" = {
                  mountpoint = "/persistent";
                  mountOptions = [
                    "noatime"
                    "compress-force=zstd:5"
                  ];
                };
                "@snapshots".mountpoint = "/snapshots";
              };
            };
          };
        };
      };
    };
  };
}
