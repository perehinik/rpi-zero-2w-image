# Raspberry Pi Zero 2w image builder

To build image in docker run:
```shell
./build-in-docker.sh -v minimal
```
or
```shell
./build-in-docker.sh -v xfce
```

Images can be found in `dist` directory.

You can also build in your local environment by running:
```shell
./build.sh -v minimal
```
or
```shell
./build.sh -v xfce
```
