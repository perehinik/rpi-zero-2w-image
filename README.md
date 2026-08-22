# Raspberry Pi Zero 2w image builder

To build image in docker run:
```shell
./build.sh -d -n air-quality
```

Images can be found in `dist` directory.

You can also build in your local environment by running:
```shell
./build.sh -n air-quality
```

To install image to SD card run
```
xzcat dist/rpi-zero-2w-bookworm-minimal-air-quality.img.xz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
```

Change `/dev/sdX` to your SD card device 