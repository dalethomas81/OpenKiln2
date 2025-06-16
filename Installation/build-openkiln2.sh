#!/bin/bash
set -e

# === Config ===
BASE_URL="https://downloads.raspberrypi.org/raspios_lite_armhf_latest"
OUTPUT_IMG="OpenKiln2-${GITHUB_SHA}.img"

# === Download base OS ===
echo "Downloading base Raspberry Pi OS Lite..."
wget -O base.zip "$BASE_URL"
unzip base.zip
BASE_IMG=$(ls *.img)

# === Copy to working image ===
cp "$BASE_IMG" "$OUTPUT_IMG"

# === Setup loop device ===
LOOP_DEV=$(sudo losetup --show -Pf "$OUTPUT_IMG")
echo "Using loop device: $LOOP_DEV"

# Map partitions
sudo kpartx -av "$LOOP_DEV"
sleep 3  # give time for /dev/mapper nodes

# Find mappings (usually loopNp1 & loopNp2)
DEVICE_NAME=$(basename $LOOP_DEV)
MNT_BOOT="/mnt/boot"
MNT_ROOT="/mnt/root"

sudo mkdir -p $MNT_BOOT $MNT_ROOT

sudo mount "/dev/mapper/${DEVICE_NAME}p1" $MNT_BOOT
sudo mount "/dev/mapper/${DEVICE_NAME}p2" $MNT_ROOT

# === Bind mount host OS folders for chroot ===
sudo mount --bind /dev $MNT_ROOT/dev
sudo mount --bind /proc $MNT_ROOT/proc
sudo mount --bind /sys $MNT_ROOT/sys

# === Copy QEMU for ARM emulation ===
sudo cp /usr/bin/qemu-arm-static $MNT_ROOT/usr/bin/

# === Copy your installer ===
SCRIPT_DIR=$(dirname "$0")
sudo cp "$SCRIPT_DIR/install.sh" $MNT_ROOT/root/

# === Run your installer in chroot ===
sudo chroot $MNT_ROOT /bin/bash -c "chmod +x /root/install.sh && /root/install.sh"

# === Clean up ===
sudo umount $MNT_ROOT/dev
sudo umount $MNT_ROOT/proc
sudo umount $MNT_ROOT/sys
sudo umount $MNT_BOOT
sudo umount $MNT_ROOT

sudo kpartx -dv "$LOOP_DEV"
sudo losetup -d "$LOOP_DEV"

echo "✅ Image built: $OUTPUT_IMG"
