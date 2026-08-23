#!/bin/bash
set -e

DOCKER_IMAGE="perehiniak/linux-build-tools:1.0.0"


rm -rf ./static/*
mkdir -p ./static/rootfs/usr/sbin/

docker run -it \
    --rm \
    --privileged \
    -e INSIDE_DOCKER=1 \
    -v ./:/root \
    -w /root \
    -u root \
    --entrypoint /bin/bash \
    "${DOCKER_IMAGE}" \
    -c 'aarch64-linux-gnu-gcc -o ./static/rootfs/usr/sbin/hello-world ./hello-world.c'

