#!/bin/bash

set -ex

CUSTOM_ISO_DIR=/home/ubuntu/ubuntu-iso/custom-iso

# Create blank FAT formatted image
dd if=/dev/zero of=efi.img bs=1M count=10
mkfs.vfat efi.img

# Create dir inside
mmd -i efi.img ::/EFI
mmd -i efi.img ::/EFI/BOOT

# Copy boot files inside
mcopy -i efi.img $CUSTOM_ISO_DIR/efi/boot/bootaa64.efi ::/EFI/BOOT/
mcopy -i efi.img $CUSTOM_ISO_DIR/efi/boot/grubaa64.efi ::/EFI/BOOT/
mcopy -i efi.img $CUSTOM_ISO_DIR/boot/grub/grub.cfg ::/EFI/BOOT/

cp efi.img $CUSTOM_ISO_DIR/boot/efi.img
