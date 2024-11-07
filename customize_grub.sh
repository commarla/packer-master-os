#!/bin/bash

set -ex

CUSTOM_ISO_DIR=/home/ubuntu/ubuntu-iso/custom-iso

cat >$CUSTOM_ISO_DIR/boot/grub/grub.cfg <<EOF
set timeout=30

loadfont unicode

set menu_color_normal=white/black
set menu_color_highlight=black/light-gray

menuentry "Install Custom Ubuntu Server" {
	set gfxpayload=keep
	linux	/casper/vmlinuz ---
	initrd	/casper/initrd
}
menuentry 'UEFI Firmware Settings' {
	fwsetup
}
EOF
