# Declarative reinstall/mount layout for EVA.
#
# This is deliberately adapted to EVA's existing unencrypted Btrfs layout:
# there is no upstream AI LUKS mapper or data-disk identifier here. The device
# id and subvolumes mirror the live EVA hardware scan. `destroy,format` is
# destructive; use `--mode mount` for an already provisioned EVA disk.
{
  fileSystems."/persistent".neededForBoot = true;

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
            name = "ESP";
            start = "1M";
            end = "2G";
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
          root = {
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
                "@guix" = {
                  mountpoint = "/gnu";
                };
                "@tmp" = {
                  mountpoint = "/tmp";
                };
                "@swap" = {
                  mountpoint = "/swap";
                  swap.swapfile.size = "96G";
                };
                "@persistent" = {
                  mountpoint = "/persistent";
                  mountOptions = [
                    "noatime"
                    "compress-force=zstd:5"
                  ];
                };
                "@snapshots" = {
                  mountpoint = "/snapshots";
                };
              };
            };
          };
        };
      };
    };
  };
}
