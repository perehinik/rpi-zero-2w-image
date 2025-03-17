#!/bin/bash

ROOTFS_SRC_DIR=debian-rfs-builder
KERNEL_SRC_DIR=rpi-zero-2w-linux
IMAGE_NAME="rpi-zero-2w.img"
IMAGE_SIZE="8G"
BUILD_DIR="/tmp/rpi-image-build"

echo;echo;echo "===  PULL SUBMODULES  ===";echo;
git submodule init
git submodule update

rm -rf ./dist
mkdir ./dist
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Build kernel
echo;echo;echo "===  BUILD KERNEL  ===";echo;
cd ./${KERNEL_SRC_DIR}
./build-in-docker.sh
cd ..
cp -r -a ./${KERNEL_SRC_DIR}/dist/* "${BUILD_DIR}"

# Build rfs
echo;echo;echo "===  BUILD ROOTFS  ===";echo;
CUSTOM_STEPS_DIR="${PWD}/custom_steps"
cd ./${ROOTFS_SRC_DIR}
./build.sh -v xfce -d ${CUSTOM_STEPS_DIR}
cd ..
cp ./${ROOTFS_SRC_DIR}/dist/rootfs-*-xfce.img "${BUILD_DIR}/rootfs.img"

echo;echo;echo "===  BUILD IMAGE  ===";echo;
echo "Create ${IMAGE_SIZE} sparse image file ${IMAGE_NAME} ..."
losetup -D
dd if=/dev/zero of="${BUILD_DIR}/${IMAGE_NAME}" bs=1 count=0 seek=${IMAGE_SIZE}
parted "${BUILD_DIR}/${IMAGE_NAME}" --script \
    mklabel msdos \
    mkpart primary 4MiB 504MiB \
    mkpart primary 504MiB 100%
LOOP_DEVICE_RPI=$(losetup -fP "${BUILD_DIR}/${IMAGE_NAME}" --show)

echo "Format partitions..."
# Format partitions
mkfs.vfat -F 32 -S 512 -n bootfs "${LOOP_DEVICE_RPI}p1"
mkfs.ext4 -b 4096 -L rootfs "${LOOP_DEVICE_RPI}p2"
echo "$(blkid | grep "${LOOP_DEVICE_RPI}")"

# Set partition table type to 0x0c - this is very important
echo -e "t\n1\n0x0c\nw\n" | fdisk "${LOOP_DEVICE_RPI}"
# Check partition info
echo -e "i\n1\nq\n" | fdisk "${LOOP_DEVICE_RPI}"

echo "Mount rootfs and rpi image..."
mkdir "${BUILD_DIR}/bootfs_rpi"
mkdir "${BUILD_DIR}/rootfs_rpi"
mount -o loop "${LOOP_DEVICE_RPI}p1" "${BUILD_DIR}/bootfs_rpi"
mount -o loop "${LOOP_DEVICE_RPI}p2" "${BUILD_DIR}/rootfs_rpi"

mkdir "${BUILD_DIR}/rootfs"
LOOP_DEVICE_RFS=$(losetup -f "${BUILD_DIR}/rootfs.img" --show)
mount -o loop ${LOOP_DEVICE_RFS} ${BUILD_DIR}/rootfs

echo "Copy files...";
cp -a ${BUILD_DIR}/rootfs/. "${BUILD_DIR}/rootfs_rpi/"
cp -a ${BUILD_DIR}/lib/. "${BUILD_DIR}/rootfs_rpi/lib"
cp -r ./src/rootfs/* "${BUILD_DIR}/rootfs_rpi"

cp -r ${BUILD_DIR}/boot/* "${BUILD_DIR}/bootfs_rpi"
cp -r ./src/bootfs/* "${BUILD_DIR}/bootfs_rpi"
sync
echo;echo "bootfs:"
echo "$(ls -l "${BUILD_DIR}/bootfs_rpi")"
echo;echo "rootfs:"
echo "$(ls -l "${BUILD_DIR}/rootfs_rpi")"

echo;echo;echo "===  CLEANUP  ===";echo;
umount "${BUILD_DIR}/rootfs_rpi"
umount "${BUILD_DIR}/bootfs_rpi"
umount "${BUILD_DIR}/rootfs"
# Wait a bit for everything to properly unmount
sleep 1
losetup -d "${LOOP_DEVICE_RPI}"
losetup -d "${LOOP_DEVICE_RFS}"

echo "Save and compress image"
cp "${BUILD_DIR}/${IMAGE_NAME}" ./dist
xz -T0 -f "./dist/${IMAGE_NAME}"

rm -rf "${BUILD_DIR}"
chown -R 1000:1000 ./dist
