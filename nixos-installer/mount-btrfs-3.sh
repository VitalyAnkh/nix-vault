# NOTE: `cat shoukei.md | grep mount-1 > mount-1.sh` to generate this script
mkdir /mnt/{nix,gnu,tmp,swap,persistent,snapshots,boot}  # mount-1
mount -o compress-force=zstd:1,noatime,subvol=@nix /dev/mapper/vr-nixos /mnt/nix  # mount-1
mount -o compress-force=zstd:1,noatime,subvol=@guix /dev/mapper/vr-nixos /mnt/gnu  # mount-1
mount -o compress-force=zstd:1,subvol=@tmp /dev/mapper/vr-nixos /mnt/tmp  # mount-1
mount -o subvol=@swap /dev/mapper/vr-nixos /mnt/swap  # mount-1
mount -o compress-force=zstd:1,noatime,subvol=@persistent /dev/mapper/vr-nixos /mnt/persistent  # mount-1
mount -o compress-force=zstd:1,noatime,subvol=@snapshots /dev/mapper/vr-nixos /mnt/snapshots  # mount-1
mount /dev/nvme0n1p1 /mnt/boot  # mount-1
btrfs filesystem mkswapfile --size 64g --uuid clear /mnt/swap/swapfile  # mount-1
swapon /mnt/swap/swapfile  # mount-1
