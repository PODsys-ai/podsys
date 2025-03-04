
# Introduction to ainexus

In the software package you have downloaded, `ainexus` is an archive of a container's file system. This container includes a series of scripts that are essential for the core operation of PODsys. The container is loaded and invoked by the `podsys/install_compute.sh` script.
- Using a container file system archive (docker export) instead of a full image archive (docker save) is done to reduce the size of the package.
```
pkgs/
├── ainexus-3.1 # Docker container tarball
```

# scripts

The scripts in the repository run within the Docker container `ainexus`.

- The `root` directory has an actual path of `/root` in the container.
- The `user-data` directory has an actual path of `/user-data` in the container.
- The `core` folder contains Python monitoring code, which is ultimately packaged into a binary file and run in the ainexus container.