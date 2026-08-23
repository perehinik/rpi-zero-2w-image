# Raspberry Pi Zero 2w image builder

To build image in docker run:
```shell
./build.sh -d -n hello-world
```

`hello-world` is a recipe name.
All recipes are defined in ./recipes directory.

Each recipe defines steps in `IMAGE_INGREDIENTS=()` list.
All steps are defined in ./src directory.

Example of step directory tree:
src/hello-world
├── build.sh
├── .gitignore
├── static
│   ├── rootfs
│   └── bootfs
└── rfs-mod
    └── run.sh

Here is a sequence of step execution:
    1. Run `build.sh` in ./src/hello-world.
       This can be used to build binaries or run other preparation steps, like wget binaries fron remote storage.
       Don't forget to add built binaries and artifacts to local .gitignore file.
    2. Copy all files from `rfs-mod` into filesystem in temporary location and run `run.sh`.
       This is executed in emulated filesystem and is very useful for installing packages, creating users, modifying permissions, etc..
    3. Copy all static files from `static/rootfs` and `static/bootfs` to corresponding locations in real rfs.

Each of those 3 steps is optional.

To rebuild only image and use previously built kernel and rootfs run:
```shell
./build.sh -d -n hello-world -i
```

To show all options:
```shell
./build.sh -h
```

Images can be found in `dist` directory.

You can also build in your local environment by running:
```shell
./build.sh -n hello-world
```

To install image to SD card run
```
xzcat dist/rpi-zero-2w-bookworm-minimal-hello-world.img.xz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
```

Change `/dev/sdX` to your SD card device
