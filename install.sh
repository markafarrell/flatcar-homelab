#! /usr/bin/bash

set -eou pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

pushd $SCRIPT_DIR >/dev/null

TARGET=${TARGET:-k0}
DEVICE=${DEVICE:-sda}

CEPH_PARTITION_SIZE=${CEPH_PARTITION_SIZE:-425G}

sudo umount /dev/${DEVICE}* || true

# Render manifests
source butane/manifests/render.sh

# Render butane
source butane/render.sh

# Generate ignition
docker run \
    --rm -i \
    -v $PWD:/data:ro \
    quay.io/coreos/butane:latest --strict --files-dir=/data < butane/$TARGET.yml > ignition/$TARGET.json

# Install flatcar
sudo $HOME/.local/bin/flatcar-install \
    -v \
    -d /dev/$DEVICE \
    -C stable -B arm64-usr -o '' \
    -i ignition/$TARGET.json \
    -f flatcar_production_image.bin.bz2

UEFI_DIR=$PWD/uefi
FW_VARS=$UEFI_DIR/fw-vars.json


efipartition=$(lsblk /dev/$DEVICE -oLABEL,PATH | awk '$1 == "EFI-SYSTEM" {print $2}')
mkdir /tmp/efipartition || true
sudo mount ${efipartition} /tmp/efipartition
pushd /tmp/efipartition
version=$(curl --silent "https://api.github.com/repos/pftf/RPi4/releases/latest" | jq -r .tag_name)
# version="v1.38"
sudo curl -LO https://github.com/pftf/RPi4/releases/download/${version}/RPi4_UEFI_Firmware_${version}.zip
sudo unzip RPi4_UEFI_Firmware_${version}.zip
sudo rm RPi4_UEFI_Firmware_${version}.zip

# Disable 3GB Memory limit
sudo virt-fw-vars \
    --input RPI_EFI.fd \
    --output RPI_EFI.fd \
    --set-json "$FW_VARS"
sudo virt-fw-vars \
    --input RPI_EFI.fd \
    --print

sudo sed -i 's/device_tree_address=0x1f0000/device_tree_address=0x3e0000/' config.txt
sudo sed -i 's/device_tree_end=0x200000/device_tree_end=0x400000/' config.txt

# sudo curl -L \
#     https://github.com/raspberrypi/firmware/raw/refs/heads/master/boot/overlays/rpi-poe-plus.dtbo \
#     --output /tmp/efipartition/overlays/rpi-poe-plus.dtbo

sudo curl -L \
    https://github.com/raspberrypi/firmware/raw/refs/heads/master/boot/overlays/rpi-poe.dtbo \
    --output /tmp/efipartition/overlays/rpi-poe.dtbo

# sudo cp $UEFI_DIR/rpi-poe.dtbo /tmp/efipartition/overlays/rpi-poe.dtbo

sudo curl -L \
    https://github.com/raspberrypi/firmware/raw/refs/heads/master/boot/overlays/pcie-32bit-dma.dtbo \
    --output /tmp/efipartition/overlays/pcie-32bit-dma.dtbo

cat <<EOF | unix2dos | sudo tee -a /tmp/efipartition/config.txt
dtoverlay=pcie-32bit-dma
dtoverlay=rpi-poe
dtparam=poe_fan_temp0=50000
dtparam=poe_fan_temp1=60000
dtparam=poe_fan_temp2=70000
dtparam=poe_fan_temp3=80000
EOF

popd
sudo umount /tmp/efipartition

sudo sgdisk --print /dev/$DEVICE
# Expand size of disk
sudo sgdisk --move-second-header /dev/$DEVICE
sudo sgdisk --print /dev/$DEVICE
# Partition rest of disk
sudo sgdisk --new=10:-$CEPH_PARTITION_SIZE:-0G /dev/$DEVICE
sudo sgdisk -c 10:CEPH /dev/$DEVICE
sudo sgdisk --print /dev/$DEVICE


source butane/manifests/clean.sh
source butane/clean.sh
source ignition/clean.sh

popd >/dev/null
