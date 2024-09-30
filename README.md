# WRF and WPS Containerized in Docker/Podman

This repository contains files for containerizing the [Weather Research & Forecasting Model (WRF)](https://www.mmm.ucar.edu/models/wrf) and the [WRF Preprocessing System (WPS)](https://github.com/wrf-model/WPS).

**Note:** The developers of WRF and WPS request that every user register at: https://www2.mmm.ucar.edu/wrf/users/download/wrf-regist.php.

## Motivation

The WRF and WPS projects are quite complex to build due to numerous dependencies. Additionally, the [WRF_DOCKER](https://github.com/NCAR/WRF_DOCKER) containerization project by John Exby and Kate Fossell has not been updated for 3 years. Therefore, this project was created to provide quick access to WRF/WPS binaries.

## Usage

1. Clone this project and `cd` into its directory.
2. Execute `podman build . --build-arg-file=argfile.conf --tag=wrf_wps:latest`. You can change the tag as desired. If using Docker, replace `podman` with `docker`.
3. Use the WPS and WRF executables in the resulting image. They are located at `/build/WPS` and `/build/WRF/run`.

You may find it helpful to mount your data directory when running the container, start a bash session in the container, and work from there. The [tutorial from the WRF_DOCKER project](https://github.com/NCAR/WRF_DOCKER/blob/master/README_tutorial.md) may also be useful.

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

Versions of dependencies provided by Conan can be updated by updating all the `conanfile-*.txt` files. Versions of source-built projects can be updating the `argfile.conf`. Several build configuration can also be changed by updating the `argfile.conf`.

Projects labelled as "patch needed" cannot be upgraded directly as there may be mismatch between the patches and the updated source, so the patches need to be updated accordingly. The patches in this folder without commit ID correspond to the versions above, and patches with commit ID are given as a reference for upgrading.
