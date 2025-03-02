# NOTE: `cat README.md | grep part-1 > part-1.sh` to generate this script
parted /dev/nvme0n1 -- mklabel gpt  # part-1
parted /dev/nvme0n1 -- mkpart ESP fat32 2MB 2047MB  # part-1
parted /dev/nvme0n1 -- set 1 esp on  # part-1
parted /dev/nvme0n1 -- mkpart primary 2048MB 100%  # part-1
