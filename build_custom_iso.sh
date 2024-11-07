#!/usr/bin/env bash

set -ex

usage() {
    echo "DISTRIB and ARCH must be provided"
    echo "DISTRIB must be one of: noble"
    echo "ARCH must be one of: amd64, arm64"
    exit 1
}

if [ -z "$DISTRIB" ] || [ -z "$ARCH" ]; then
    usage
fi

NOBLE_ARM_ISO_URL=https://cdimage.ubuntu.com/releases/24.04/release/ubuntu-24.04.1-live-server-arm64.iso
NOBLE_AMD_ISO_URL=https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server-amd64.iso

case "$DISTRIB-$ARCH" in
    "noble-amd64")
        BASE_ISO_URL=$NOBLE_AMD_ISO_URL
        ;;
    "noble-arm64")
        BASE_ISO_URL=$NOBLE_ARM_ISO_URL
        ;;
    *)
        usage
        ;;
esac

MOUNT_DIR=~/ubuntu-iso/mount
CUSTOM_ISO_DIR=~/ubuntu-iso/custom-iso
SQUASHFS_ROOT_DIR=~/ubuntu-iso/squashfs-root

# Download the Ubuntu Server ISO
wget -q -O /tmp/ubuntu.iso $BASE_ISO_URL

# Mount and extract the ISO
mkdir -p $MOUNT_DIR $CUSTOM_ISO_DIR $SQUASHFS_ROOT_DIR
sudo mount -o loop /tmp/ubuntu.iso $MOUNT_DIR
rsync -a $MOUNT_DIR/ $CUSTOM_ISO_DIR/
sudo umount $MOUNT_DIR
sudo unsquashfs -d $SQUASHFS_ROOT_DIR $CUSTOM_ISO_DIR/casper/ubuntu-server-minimal.squashfs
sudo unsquashfs -f -no-exit-code -d $SQUASHFS_ROOT_DIR $CUSTOM_ISO_DIR/casper/ubuntu-server-minimal.ubuntu-server.squashfs

# Mount necessary directories for chroot
sudo mount -o bind /dev $SQUASHFS_ROOT_DIR/dev
sudo mount -o bind /run $SQUASHFS_ROOT_DIR/run
sudo mount -t proc /proc $SQUASHFS_ROOT_DIR/proc
sudo mount -t sysfs /sys $SQUASHFS_ROOT_DIR/sys
sudo mount -t devpts /dev/pts $SQUASHFS_ROOT_DIR/dev/pts

# Copy custom scripts to chroot
cp -r /tmp/customize_squashfs.sh $SQUASHFS_ROOT_DIR/tmp/
sudo chmod +x $SQUASHFS_ROOT_DIR/tmp/customize_squashfs.sh

# Chroot into the extracted filesystem
sudo chroot $SQUASHFS_ROOT_DIR /tmp/customize_squashfs.sh

# Unmount directories
sudo umount $SQUASHFS_ROOT_DIR/dev/pts
sudo umount $SQUASHFS_ROOT_DIR/proc
sudo umount $SQUASHFS_ROOT_DIR/sys
sudo umount $SQUASHFS_ROOT_DIR/dev
sudo umount $SQUASHFS_ROOT_DIR/run

# Create a new squashfs image
sudo rm $CUSTOM_ISO_DIR/casper/ubuntu-server-minimal.ubuntu-server.squashfs
sudo mksquashfs $SQUASHFS_ROOT_DIR $CUSTOM_ISO_DIR/casper/ubuntu-server-minimal.ubuntu-server.squashfs -no-progress -info

# Create the EFI partition
sudo chmod +x /tmp/create_efi_partition.sh
sudo /tmp/create_efi_partition.sh

# Customize the GRUB configuration
sudo chmod +x /tmp/customize_grub.sh
sudo /tmp/customize_grub.sh

# Copy autoinstall file
sudo cp /tmp/autoinstall.yaml $CUSTOM_ISO_DIR/

# Create the new ISO
sudo chroot $SQUASHFS_ROOT_DIR dpkg-query -W --showformat='${Package} ${Version}\n' | sudo tee $CUSTOM_ISO_DIR/casper/filesystem.manifest

sudo xorriso -as mkisofs -D -r \
    -V "Custom Ubuntu Server" \
    -J -joliet-long -l \
    -partition_offset 16 -partition_cyl_align all \
    -append_partition 2 0xef $CUSTOM_ISO_DIR/boot/efi.img \
    -e boot/efi.img \
    -no-emul-boot \
    -o /tmp/custom-ubuntu.iso $CUSTOM_ISO_DIR

echo "ISO has been created"
