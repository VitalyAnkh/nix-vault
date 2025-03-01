# NOTE: `cat shoukei.md | grep create-bcachefs > bcachefs.sh` to generate this script
mkfs.fat -F 32 -n ESP /dev/nvme0n1p1  # create-bcachefs
mkfs.bcachefs -L vr-nixos /dev/nvme0n1p2   # create-bcachefs
mount /dev/mapper/vr-nixos /mnt  # create-bcachefs
bcachefs subvolume create /mnt/@nix  # create-bcachefs
bcachefs subvolume create /mnt/@guix  # create-bcachefs
bcachefs subvolume create /mnt/@tmp  # create-bcachefs
bcachefs subvolume create /mnt/@swap  # create-bcachefs
bcachefs subvolume create /mnt/@persistent  # create-bcachefs
bcachefs subvolume create /mnt/@snapshots  # create-bcachefs
umount /mnt  # create-bcachefs
