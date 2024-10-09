# WRF and WPS Containerized in Docker/Podman

This repository contains files for containerizing the [Weather Research & Forecasting Model (WRF)](https://www.mmm.ucar.edu/models/wrf) and the [WRF Preprocessing System (WPS)](https://github.com/wrf-model/WPS).

**Note:** The developers of WRF and WPS request that every user register at: https://www2.mmm.ucar.edu/wrf/users/download/wrf-regist.php.

## Motivation

The WRF and WPS projects are quite complex to build due to numerous dependencies. Additionally, the [WRF_DOCKER](https://github.com/NCAR/WRF_DOCKER) containerization project by John Exby and Kate Fossell has not been updated for 3 years. Therefore, this project was created to provide quick access to WRF/WPS binaries.

Two versions of Containerfile are provided, one for Ubuntu and one for Alma Linux. Also, almost all dependencies (except glibc and libgfortran etc.) are built from source and statically linked, instead of pulled from the system package manager, making it easier to directly copy built binaries from the containers to run on bare systems if container is unavailable on the production environment.

Future possible improvement:
1. Statically link the math and quadmath library, glibc and gfortran library.
2. Set `rpath` during linkage when building WRF and WPS so the MPICH dynamic libraries can be automatically located.

## Usage 1: Usage in Docker/Podman

Use this version if you can use Docker or Podman to call WRF/WPS binaries in your production environment.

1. Clone this project and `cd` into its directory.
2. Make desired change to `argfile.conf`.
3. For Podman users, execute `podman build . --build-arg-file=argfile.conf --tag=wrf_wps:latest`. You can change the tag as desired.  
   For Docker users, execute `docker build -f Containerfile --tag=wrf_wps:latest --build-arg abcd=efgh .`. Refer to `argfile.conf` for possible `build-arg`s values as Docker does not support `build-arg-file` yet.
4. Use the WPS and WRF executables in the resulting image to execute the image. They are located at `/build/WPS` and `/build/WRF/run`.

You may find it helpful to mount your data directory when running the container, start a bash session in the container, and work from there. The [tutorial from the WRF_DOCKER project](https://github.com/NCAR/WRF_DOCKER/blob/master/README_tutorial.md) may also be useful.

## Usage 2: Build in container and copy out the binaries

Some production environments have no container access, even for a rootless one. Another case is that WPS and WRF commands are called by other processes or scripts, where calling into Podman/Docker is complicated. In those cases, you may want to build binaries in the container and copy out the binaries for direct usage.

Two versions of base image are provided:

- `Containerfile` uses Ubuntu 24.04
- `Containerfile_almalinux` uses 8.10
- Well, it should not be *that* difficult to port to a new host system/version.

1. Clone this project and `cd` into its directory.
2. Make desired change to `argfile.conf`.
3. For Podman users, execute `podman build . -f Containerfile --build-arg-file=argfile.conf --tag=wrf_wps:latest`. You can change the tag as desired. For Almalinux host, change `Containerfile` to `Containerfile_almalinux`.  
   For Docker users, execute `docker build -f Containerfile --tag=wrf_wps:latest --build-arg abcd=efgh .`. Refer to `argfile.conf` for possible `build-arg`s values as Docker does not support `build-arg-file` yet. For Almalinux host, change `Containerfile` to `Containerfile_almalinux`.
4. Use the following commands to copy out binaries (change podman to docker if needed, and fill `<cont-id>` with the container id you get from Step 3).

```
podman cp <cont-id>:/build/WRF ./out/WRF
podman cp <cont-id>:/build/WPS ./out/WPS
podman cp <cont-id>:/install_dir/mpich ./out/mpich
```

You can now use the binaries in `./out/WRF/run` and `./out/WPS`. You may need to add `(absolute path to .)/out/mpich/lib` into `LD_LIBRARY_PATH` before running, and it is a good idea to append this to your bash/zsh/fish profile.

## Build Info

To build the WRF and WPS binaries, several dependency libraries must be built first. Multiple package managers and build tools are involved.

By default, WPS and WRF are built in the x86_64, dmpar, em_real configuration.

| Project | Version | Build | Patch Needed |
| :-----: | :-----: | :---: | :----------: |
| libcurl | 8.10.1  | Resolved via Conan | No |
| jasper  | 4.2.4   | Resolved via Conan | No |
| libpng  | 1.6.44  | Resolved via Conan | No |
| szip    | 2.1.1   | Resolved via Conan with encoding feature enabled | No |
| zlib    | 1.3.1   | Resolved via Conan | No |
| libxml2 | 2.13.4  | Resolved via Conan | No |
| MPICH   | v4.2.3rc1 | Built from source using autoconf + make. | No |
| HDF5    | 1.14.4.3  | Built from source using CMake + ninja    | Yes |
| netcdf-c | v4.9.3-rc1 | Built from source using CMake + ninja  | Yes |
| netcdf-fortran | v4.6.1 | Built from source using CMake + ninja | Yes |
| WRF | v4.6.0 | Built from source using configure + make | Yes |
| WPS | v4.6.0 | Built from source using configure + make | Yes |

Versions of dependencies provided by Conan can be updated by updating all the `conanfile-*.txt` files. Versions of source-built projects can be updating the `argfile.conf`. Several build configuration can also be changed by updating the `argfile.conf` if you are building using Podman, or by passing a `build-arg` if you are building using Docker.

Projects labelled as "patch needed" cannot be upgraded directly as there may be mismatch between the patches and the updated source, so the patches need to be updated accordingly. The patches in this folder without commit ID correspond to the versions above, and patches with commit ID are given as a reference for upgrading.

## License & Contribution

MIT License. Feel free to open issue/PRs.
