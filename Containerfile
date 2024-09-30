FROM ubuntu:24.04 as compiler

WORKDIR /build
ENV DEBIAN_FRONTEND=noninteractive


# Install tools
RUN apt update \
    && apt install -y gcc g++ gfortran binutils libtool autoconf automake perl ninja-build curl wget python3 python3-pip pipx git cmake jq csh time

# Prepare source-build files
RUN mkdir -p /install_dir/{netcdf,mpich,hdf5} /install_dir/netcdf/plugin_dir \
    && git clone https://github.com/Unidata/netcdf-c.git \
    && git clone https://github.com/Unidata/netcdf-fortran.git \
    && git clone --recursive https://github.com/pmodels/mpich.git \
    && git clone https://github.com/wrf-model/WRF.git \
    && git clone https://github.com/wrf-model/WPS.git \
    && git clone https://github.com/HDFGroup/hdf5.git \
    && mkdir /build/netcdf-fortran/build /build/netcdf-c/build /build/hdf5/build
COPY conanfile-netcdf.txt /build/netcdf-c/conanfile.txt
COPY conanfile-netcdf.txt /build/netcdf-fortran/conanfile.txt
COPY conanfile-wps.txt /build/WPS/conanfile.txt
COPY conanfile-hdf5.txt /build/hdf5/conanfile.txt


# Prepare dependencies conan
ENV PATH="/root/.local/bin:$PATH"
RUN pipx install conan \
    && conan profile detect \
    && cd /build/netcdf-c \
    && conan install . --build missing --output-folder=build -s build_type=Release \
    && cd /build/netcdf-fortran \
    && conan install . --build missing --output-folder=build -s build_type=Release \
    && cd /build/hdf5 \
    && conan install . --build missing --output-folder=build -s build_type=Release \
    && cd /build/WPS \
    && conan install . --build missing --format json > conaninfo.json


COPY netcdf-c-cmake.patch /build/netcdf-c/netcdf-c-cmake.patch
COPY netcdf-fortran-cmake.patch /build/netcdf-fortran/netcdf-fortran-cmake.patch
COPY hdf5-cmake.patch /build/hdf5/hdf5-cmake.patch
COPY wps.patch /build/WPS/wps.patch
COPY wrf.patch /build/WRF/wrf.patch


# Build MPICH
ARG mpich_version=v4.2.3rc1
RUN cd /build/mpich \
    && git checkout $mpich_version \
    && ./autogen.sh \
    && ./configure --prefix=/install_dir/mpich \
    && make -j$(nproc) \
    && make install


# Build HDF5
ARG hdf5_version=hdf5_1.14.4.3
RUN cd /build/hdf5 \
    && git checkout $hdf5_version \
    && git apply hdf5-cmake.patch \
    && cd build \
    && cmake .. -G Ninja --preset conan-release \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/install_dir/hdf5 \
        -DBUILD_STATIC_LIBS=ON \
        -DBUILD_SHARED_LIBS=OFF \
        -DHDF5_BUILD_CPP_LIB=ON \
        -DHDF5_BUILD_FORTRAN=ON \
        -DHDF5_ENABLE_SZIP_SUPPORTL=ON \
        -DHDF5_ENABLE_PARALLEL=OFF \
    && cmake --build . \
    && cmake --install .


# Build NetCDF-C
ARG netcdf_c_version=v4.9.3-rc1
RUN cd /build/netcdf-c \
    && git checkout $netcdf_c_version \
    && git apply netcdf-c-cmake.patch \
    && cd build \
    && cmake .. -G Ninja --preset conan-release \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_PREFIX_PATH=/install_dir/hdf5/cmake \
        -DCMAKE_INSTALL_PREFIX=/install_dir/netcdf \
        -DNETCDF_PLUGIN_INSTALL_DIR=/install_dir/netcdf/plugin_dir \
        -DBUILD_SHARED_LIBS=OFF \
    && cmake --build . \
    && cmake --install .


# Build NetCDF-Fortran
RUN rm /bin/sh && ln -s /bin/bash /bin/sh
ARG netcdf_fortran_version=v4.6.1
RUN cd /build/netcdf-fortran \
    && git checkout $netcdf_fortran_version \
    && git apply netcdf-fortran-cmake.patch \
    && cd build \
    && cmake .. -G Ninja --preset conan-release \
        "-DCMAKE_PREFIX_PATH=/install_dir/netcdf/lib/cmake/netCDF;/install_dir/hdf5/cmake" \
        -DCMAKE_INSTALL_PREFIX=/install_dir/netcdf \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF \
    && cmake --build . \
    && cmake --install .


# Build WRF
ENV PATH="/install_dir/mpich/bin:/install_dir/netcdf/bin:$PATH"
ARG wrf_version=v4.6.0
ARG wrf_config_1=34
ARG wrf_config_2=1
ARG wrf_type=em_real
RUN cd /build/WRF \
    && source /build/WPS/conanautotoolsdeps.sh \
    && export JASPER=$(cat /build/WPS/conaninfo.json | jq -r '.graph.nodes | [.[] | select(.name == "jasper")] | first | .package_folder') \
    && export HDF5=/install_dir/hdf5 \
    && export NETCDF=/install_dir/netcdf \
    && export LDFLAGS="-L$HDF5/lib $LDFLAGS" LIBS="-lhdf5_hl -lhdf5_fortran -lhdf5_tools -lhdf5 $LIBS" \
    && git checkout $wrf_version \
    && git apply wrf.patch \
    && { echo $wrf_config_1; echo $wrf_config_2; } | ./configure \
    && ./compile $wrf_type \
    && source /build/WPS/deactivate_conanautotoolsdeps.sh \
    && test -f run/wrf.exe


# Build WPS
ARG wps_version=v4.6.0
ARG wps_config=3
RUN cd /build/WPS \
    && source /build/WPS/conanautotoolsdeps.sh \
    && export JASPER=$(cat conaninfo.json | jq -r '.graph.nodes | [.[] | select(.name == "jasper")] | first | .package_folder') \
    && export PNG=$(cat conaninfo.json | jq -r '.graph.nodes | [.[] | select(.name == "libpng")] | first | .package_folder') \
    && export JPEG=$(cat conaninfo.json | jq -r '.graph.nodes | [.[] | select(.name == "libjpeg")] | first | .package_folder') \
    && export HDF5=/install_dir/hdf5 \
    && export NETCDF=/install_dir/netcdf JASPERLIB="$JASPER/lib" JASPERINC="$JASPER/include" \
    && export LDFLAGS2="-L$HDF5/lib $LDFLAGS" LIBS2="-lhdf5_hl -lhdf5_fortran -lhdf5_tools -lhdf5 $LIBS" \
    && git checkout $wps_version \
    && git apply wps.patch \
    && echo $wps_config | ./configure \
    && ./compile \
    && source /build/WPS/deactivate_conanautotoolsdeps.sh \
    && test -f ungrib/ungrib.exe


# Runner
FROM ubuntu:24.04 as runner

RUN mkdir /build && mkdir /install_dir && apt update && apt install -y gcc g++ gfortran
COPY --from=compiler /build/WRF /build/WRF
COPY --from=compiler /build/WPS /build/WPS
COPY --from=compiler /install_dir /install_dir

WORKDIR /build/WPS
CMD ["/bin/bash"]