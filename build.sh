#!/bin/bash

ROOTFS_SRC_DIR=debian-rfs-builder
KERNEL_SRC_DIR=rpi-zero-2w-linux
IMAGE_VERSION="xfce"
IMAGE_SIZE="8GB"
BUILD_DIR="/tmp/rpi-image-build"
BUILD_ALL=1
BUILD_KERNEL=0
BUILD_ROOTFS=0
BUILD_IMAGE=0

# Function to display help message
show_help() {
    echo "Usage: $(basename "$0") [-v <version> ]"
    echo ""
    echo "Options:"
    echo " -v <version>  minimal | xfce"
    echo " -k            Build kernel"
    echo " -r            Build rootfs"
    echo " -i            Build image"
    echo " -h            Show this help message."
}

# Parse options
while getopts "v:krih" opt; do
    case $opt in
        v)
            IMAGE_VERSION=$OPTARG
	    ;;
	k)
	    BUILD_KERNEL=1
	    BUILD_ALL=0
	    ;;
	r)
	    BUILD_ROOTFS=1
	    BUILD_ALL=0
	    ;;
	i)
	    BUILD_IMAGE=1
	    BUILD_ALL=0
	    ;;
        h)
            show_help
            exit 0
            ;;
        \?)
            show_help
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            show_help
            exit 1
            ;;
    esac
done

if [ "${IMAGE_VERSION}" = "xfce" ]; then
     IMAGE_NAME="rpi-zero-2w-bookworm-xfce.img"
     POSTINST_SCRIPT="${PWD}/postinst/postinst-xfce.sh"
elif [ "${IMAGE_VERSION}" = "minimal" ]; then
     IMAGE_NAME="rpi-zero-2w-bookworm-minimal.img"
     POSTINST_SCRIPT="${PWD}/postinst/postinst-minimal.sh"
else
     echo "Wrong version ${IMAGE_VERSION}"
     exit 1
fi

if [ "${BUILD_KERNEL}" = "1" ] || [ "${BUILD_ALL}" = "1" ]; then
    # Build kernel
    echo;echo;echo "===  BUILD KERNEL  ===";echo;
    cd ./${KERNEL_SRC_DIR}
    ./build.sh
    cd ..
fi

if [ "${BUILD_ROOTFS}" = "1" ] || [ "${BUILD_ALL}" = "1" ]; then
    # Build rfs
    echo;echo;echo "===  BUILD ROOTFS  ===";echo;
    cd ./${ROOTFS_SRC_DIR}
    ./build.sh -v minimal -x ${POSTINST_SCRIPT}
    cd ..
fi

if [ "${BUILD_IMAGE}" = "0" ] && [ "${BUILD_ALL}" = "0" ]; then
    exit 0
fi

echo;echo;echo "===  BUILD IMAGE  ===";echo;
# Create directories
mkdir -p ./dist
rm -f ./dist/${IMAGE_NAME}
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Copy kernel and rootfs
cp -r -a ./${KERNEL_SRC_DIR}/dist/* "${BUILD_DIR}"
cp ./${ROOTFS_SRC_DIR}/dist/rootfs-*.img "${BUILD_DIR}/rootfs.img"

echo "Create ${IMAGE_SIZE} sparse image file ${IMAGE_NAME} ..."
losetup -D
dd if=/dev/zero of="${BUILD_DIR}/${IMAGE_NAME}" bs=1 count=0 seek=${IMAGE_SIZE}
parted "${BUILD_DIR}/${IMAGE_NAME}" --script \
    mklabel msdos \
    mkpart primary 4MB 512MB \
    mkpart primary 512MB 100%
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
