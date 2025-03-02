# NOTE: `cat shoukei.md | grep create-btrfs > btrfs.sh` to generate this script
mkfs.fat -F 32 -n ESP /dev/nvme0n1p1  # create-btrfs
mkfs.btrfs -L vr-nixos /dev/mapper/vr-nixos   # create-btrfs
mount /dev/mapper/vr-nixos /mnt  # create-btrfs
btrfs subvolume create /mnt/@nix  # create-btrfs
btrfs subvolume create /mnt/@guix  # create-btrfs
btrfs subvolume create /mnt/@tmp  # create-btrfs
btrfs subvolume create /mnt/@swap  # create-btrfs
btrfs subvolume create /mnt/@persistent  # create-btrfs
btrfs subvolume create /mnt/@snapshots  # create-btrfs
umount /mnt  # create-btrfs
