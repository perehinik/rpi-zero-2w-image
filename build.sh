#!/bin/bash
set -e

ROOTFS_SRC_DIR=debian-rfs-builder
KERNEL_SRC_DIR=rpi-zero-2w-linux
IMAGE_SIZE="8GB"
BUILD_DIR="./rpi-image-build"
BUILD_ALL=1
BUILD_KERNEL=0
BUILD_ROOTFS=0
BUILD_IMAGE=0
DOCKER_OPTIONS=""
DOCKER_IMAGE="perehiniak/linux-build-tools:1.0.1"
RECIPE_NAME=""

print_step() {
    echo
    echo
    echo "=== $1 ==="
    echo
}

# Function to display help message
show_help() {
    echo "Usage: $(basename "$0") -n <recipe name> [ -d ] [ -kri ] [-v <version> ]"
    echo ""
    echo "Options:"
    echo " -n <recipe name>   Recipe name, all recipe files should be in recipe-<recipe name> dir"
    echo " -k                 Build kernel"
    echo " -r                 Build rootfs"
    echo " -i                 Build image"
    echo " -d                 Run inside Docker."
    echo " -h                 Show this help message."
}

# Parse options
while getopts "v:n:kridh" opt; do
    case $opt in
        n)
            RECIPE_NAME=$OPTARG
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
        d)
            DOCKER_OPTIONS="-d"
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

print_step "GET RECIPE ${RECIPE_NAME}"
source ./recipes/${RECIPE_NAME}

IMAGE_NAME="rpi-zero-2w-bookworm-${IMAGE_VERSION}-${RECIPE_NAME}.img"

# No need to run in Docker, as it already built at that point
if [ "${BUILD_KERNEL}" = "1" ] || [ "${BUILD_ALL}" = "1" ] && [ -z "${INSIDE_DOCKER:-}" ]; then
    # Build kernel
    print_step "BUILD KERNEL"
    cd ./${KERNEL_SRC_DIR}
    ./build.sh "${DOCKER_OPTIONS}"
    cd ..
fi

# No need to run in Docker, as it already built at that point
if [ "${BUILD_ROOTFS}" = "1" ] || [ "${BUILD_ALL}" = "1" ] && [ -z "${INSIDE_DOCKER:-}" ]; then
    # Build rfs
    print_step "BUILD ROOTFS"
    cd ./${ROOTFS_SRC_DIR}
    ./build.sh -v ${IMAGE_VERSION} "${DOCKER_OPTIONS}"
    cd ..
fi

if [ "${BUILD_IMAGE}" = "0" ] && [ "${BUILD_ALL}" = "0" ]; then
    exit 0
fi

# Do this only outside docker and just mount build dit in docker.
if [ -z "${INSIDE_DOCKER:-}" ]; then
    print_step "BUILD IMAGE"
    # Create directories
    mkdir -p ./dist
    rm -f ./dist/${IMAGE_NAME}
    rm -rf "${BUILD_DIR}"
    mkdir -p "${BUILD_DIR}"

    print_step "COPY FILES"
    cp -r -a ./${KERNEL_SRC_DIR}/dist/* "${BUILD_DIR}"
    cp ./${ROOTFS_SRC_DIR}/dist/rootfs-bookworm-${IMAGE_VERSION}.img "${BUILD_DIR}/rootfs.img"
    sync
    ls ${BUILD_DIR}


    print_step "APPLY RECIPE ${RECIPE_NAME} RFS mods"
    for IM_INGREDIENT in "${IMAGE_INGREDIENTS[@]}"; do
        INGR_DIR="./src/${IM_INGREDIENT}"
        if [ ! -d "${INGR_DIR}" ]; then
            echo "ERROR: INGREDIENT not found: ${INGR_DIR}" >&2
            exit 1
        fi
        
        if [ -d "${INGR_DIR}/rfs-mod" ]; then
            print_step "APPLY INGREDIENT RFS mod ${IM_INGREDIENT}"
            ./debian-rfs-builder/run-in-image-ssh.sh "${DOCKER_OPTIONS}" \
                        -i "${BUILD_DIR}/rootfs.img" \
                        -s "${INGR_DIR}/rfs-mod/run.sh" \
                        -c "${INGR_DIR}/rfs-mod"
        fi
    done
fi

# If we use Docker everything from this point should be done there
if [ DOCKER_OPTIONS != "" ] && [ -z "${INSIDE_DOCKER:-}" ]; then
    print_step "START DOCKER"
    exec docker run -it \
        --rm \
	    --privileged \
        -e INSIDE_DOCKER=1 \
        -v ./:/root \
	    -v /dev:/dev \
        -w /root \
        -u root \
        --entrypoint "$0" \
        ${DOCKER_IMAGE} \
	    "$@"
fi

echo "Create ${IMAGE_SIZE} sparse image file ${IMAGE_NAME} ..."
losetup -D || true
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
mkdir -p "${BUILD_DIR}/bootfs_rpi"
mkdir -p "${BUILD_DIR}/rootfs_rpi"
mount -o loop "${LOOP_DEVICE_RPI}p1" "${BUILD_DIR}/bootfs_rpi"
mount -o loop "${LOOP_DEVICE_RPI}p2" "${BUILD_DIR}/rootfs_rpi"

mkdir -p "${BUILD_DIR}/rootfs"
LOOP_DEVICE_RFS=$(losetup -f "${BUILD_DIR}/rootfs.img" --show)
mount -o loop ${LOOP_DEVICE_RFS} ${BUILD_DIR}/rootfs

echo "Copy files...";
cp -a ${BUILD_DIR}/rootfs/. "${BUILD_DIR}/rootfs_rpi/"
cp -a ${BUILD_DIR}/lib/. "${BUILD_DIR}/rootfs_rpi/lib"
cp -r ${BUILD_DIR}/boot/* "${BUILD_DIR}/bootfs_rpi"

print_step "APPLY RECIPE ${RECIPE_NAME} STATIC FILES"
for IM_INGREDIENT in "${IMAGE_INGREDIENTS[@]}"; do
    INGR_DIR="./src/${IM_INGREDIENT}"
    if [ ! -d "${INGR_DIR}" ]; then
        echo "ERROR: INGREDIENT not found: ${INGR_DIR}" >&2
        exit 1
    fi
    
    if [ -d "${INGR_DIR}/static/rootfs" ]; then
        print_step "APPLY INGREDIENT RootFS static ${IM_INGREDIENT}"
        
        cp -ra "${INGR_DIR}/static/rootfs/." "${BUILD_DIR}/rootfs_rpi"
    fi

    if [ -d "${INGR_DIR}/static/bootfs" ]; then
        print_step "APPLY INGREDIENT BootFS static ${IM_INGREDIENT}"
        
        cp -r "${INGR_DIR}/static/bootfs/." "${BUILD_DIR}/bootfs_rpi"
    fi
done

sync
echo;echo "bootfs:"
echo "$(ls -l "${BUILD_DIR}/bootfs_rpi")"
echo;echo "rootfs:"
echo "$(ls -l "${BUILD_DIR}/rootfs_rpi")"

print_step "CLEANUP"
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
