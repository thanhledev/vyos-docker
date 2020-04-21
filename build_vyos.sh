#!/bin/bash

# parameter: $1: docker_username, $2: vyos_url path

LANG=C

set -e
set -x

# check for required packages
echo "Check for required packages"
check_pkgs=$(apt list --installed | grep -i 'overlayroot\|curl' | wc -l)
if [[ "$check_pkgs" -eq 0 ]]; then
  echo "Install required packages"
  sudo apt install overlayroot curl
fi

# change your docker tag
tag="$1/vyos"
# get the vyos downloadable url
vyos_url=$2
# local downloaded iso file path
vyos_iso_path=$(pwd)/vyos.iso
# local gpg key file path
gpg_key_local_path=$(pwd)/so3group_maintainers.key

# cdrom mount root path - used to mount the iso image
cd_root=$(pwd)/cdrom
# cd squash root path
cd_squash_root=$(pwd)/cdsquash
# filesystem squashfs path inside the cdrom mount root path
squashfs_image="${cd_root}/live/filesystem.squashfs"

# write root path - used to write data from squash filesystem
write_root=$(pwd)/wroot
# read root path - used to read data
read_root=$(pwd)/squashfs
# install root path - extract the whole /dev/sda to this dir
inst_root=$(pwd)/inst_root

# Create the necessary directories
echo "create directories"
mkdir -p ${cd_root} ${cd_squash_root} ${write_root} ${read_root} ${inst_root}

# Download VyOS ISO image
check_vyos_iso=$(ls -l | grep -i 'vyos.iso' | wc -l)
if [[ "$check_vyos_iso" -ne 1 ]]; then
  echo "Download vyos iso image"
  # Download VyOS ISO
  curl ${vyos_url} -o ${vyos_iso_path}
fi

# Mount ISO image to cd_root
sudo mount -o loop -t iso9660 ${vyos_iso_path} ${cd_root}

# Mount squashfs image from ISO
sudo mount -o loop -t squashfs ${squashfs_image} ${cd_squash_root}

# Identify version string from iso packages
version_string=$(cat ${cd_root}/live/filesystem.packages | grep ^vyatta-version | awk '{print $2}')
echo "This is version ${version_string}"

# ---- Install image from ISO ----
# Create {{ write_root }} directories
mkdir -p ${write_root}/boot/${version_string}/live-rw

# Copy squashfs image from ISO to root partition
cp -p ${squashfs_image} ${write_root}/boot/${version_string}/${version_string}.squashfs

# Copy boot files (kernel and initrd images) from ISO to root partition
find ${cd_squash_root}/boot -maxdepth 1  \( -type f -o -type l \) -exec cp -dp {} ${write_root}/boot/${version_string}/ \;

# Mount squashfs image from root partition
sudo mount -o loop -t squashfs ${write_root}/boot/${version_string}/${version_string}.squashfs ${read_root}

# Copy all files to installation directory
sudo cp -pr ${read_root}/* ${inst_root}/

## ---- VyOS configuration ----
# Make sure that config partition marker exists
sudo touch ${inst_root}/opt/vyatta/etc/config/.vyatta_config

# Copy default config file to config directory
sudo chroot --userspec=root:vyattacfg ${inst_root} cp /opt/vyatta/etc/config.boot.default /opt/vyatta/etc/config/config.boot

# Change permissions on the new config file
sudo chmod 755 ${inst_root}/opt/vyatta/etc/config/config.boot

# Add multiple interfaces eth0-eth4 and not setup address (optional)
sudo sed -i '/interfaces {/ a    ethernet eth0 {\n }\n ethernet eth1 {\n }\n ethernet eth2 {\n }\n ethernet eth3 {\n }\n ethernet eth4 {\n }' ${inst_root}/opt/vyatta/etc/config/config.boot

# Remove Linux Kernel
linux_image=$(sudo chroot ${inst_root} dpkg -l | grep linux-image | awk '{print $2}')
sudo chroot ${inst_root} apt-get -y remove --purge linux-firmware ${linux_image}
sudo chroot ${inst_root} rm -rf lib/modules/*

## ---- Generate Docker image ----
dir="$(mktemp -d $(pwd)/vyos-image.XXXXXX)"
rootfsDir=$inst_root
tarFile="$dir/rootfs.tar.xz"
touch "$tarFile"
sudo tar --numeric-owner -Jcaf "$tarFile" -C "$rootfsDir" --transform='s,^./,,' .
echo >&2 "+ cat > '$dir/Dockerfile'"
cat > "$dir/Dockerfile" <<'EOF'
FROM debian:jessie-slim
ADD rootfs.tar.xz /
ENTRYPOINT ["/sbin/init"]
EOF
# build docker image
docker build -t "$tag:latest" "$dir"

# cleanup
echo "Clean up..."
# umount root dirs
sudo umount ${read_root}
sudo umount ${cd_squash_root}
sudo umount ${cd_root}

# remove dirs
sudo rm -rf ${read_root} ${cd_squash_root} ${cd_root} ${write_root} ${inst_root} $dir
echo "Finished..."
