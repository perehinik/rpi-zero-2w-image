#!/bin/bash

DOCKER_IMAGE=perehiniak/linux-build-tools:1.0.1

docker run -it \
        --rm \
	--privileged \
        -v ./:/root \
	-v /dev:/dev \
        -w /root \
        -u root \
        --entrypoint ./build.sh \
        ${DOCKER_IMAGE}

