#!/bin/bash

set -ex

# Duplicate lists because of https://bitbucket.org/icl/magma/pull-requests/32
# Use compatible arches for CUDA 12.8 (minimum sm_60)
# Aligned with Windows build: sm_60,sm_70,sm_80,sm_90 for CUDA 12
export CUDA_ARCH_LIST="sm_60,sm_70,sm_80"
export CUDAARCHS="60-virtual;70-virtual;80-virtual"

if [[ "$cuda_compiler_version" == "11.8" ]]; then
  export CUDA_ARCH_LIST="${CUDA_ARCH_LIST},sm_90"
  export CUDAARCHS="${CUDAARCHS};90"
elif [[ "$cuda_compiler_version" == "12."* ]]; then
  export CUDA_ARCH_LIST="${CUDA_ARCH_LIST},sm_90"
  export CUDAARCHS="${CUDAARCHS};90"
else
  echo "Unsupported CUDA version. Please update build.sh"
  exit 1
fi

# Conda-forge nvcc compiler flags environment variable doesn't match CMake environment variable
# Redirect it so that the flags are added to nvcc calls
export CUDAFLAGS="${CUDAFLAGS} ${CUDA_CFLAGS}"

# Compress SASS and PTX in the binary to reduce disk usage
export CUDAFLAGS="${CUDAFLAGS} -Xfatbin -compress-all"

# Suppress deprecation warnings
export CUDAFLAGS="${CUDAFLAGS} -Wno-deprecated-gpu-targets"
export CXXFLAGS="${CXXFLAGS} -Wno-deprecated-declarations"

# Set MKL configuration (aligned with Windows)
export MKLROOT=$PREFIX
export BLA_VENDOR=Intel10_64lp

mkdir build
cd build

cmake $SRC_DIR \
  -G "Ninja" \
  -DBUILD_SHARED_LIBS:BOOL=ON \
  -DCMAKE_BUILD_TYPE=Release \
  -DGPU_TARGET=$CUDA_ARCH_LIST \
  -DMAGMA_ENABLE_CUDA:BOOL=ON \
  -DUSE_FORTRAN:BOOL=OFF \
  -DMAGMA_WITH_MKL:BOOL=ON \
  -DMKLROOT=$MKLROOT \
  -DBLA_VENDOR=$BLA_VENDOR \
  -DCMAKE_CUDA_SEPARABLE_COMPILATION:BOOL=OFF \
  ${CMAKE_ARGS}

# Build both magma and magma_sparse (unlike conda-forge which only builds magma_sparse)
cmake --build . \
    --config Release \
    --parallel ${CPU_COUNT} \
    --target magma magma_sparse \
    --verbose

# Strip binaries to reduce size
$STRIP ./lib/libmagma.so
$STRIP ./lib/libmagma_sparse.so

# Install libraries
install ./lib/libmagma.so $PREFIX/lib/libmagma.so
install ./lib/libmagma_sparse.so $PREFIX/lib/libmagma_sparse.so

# Install headers
cd ..
mkdir -p $PREFIX/include
cp -pr ./include/*.h $PREFIX/include
cp -pr ./sparse/include/*.h $PREFIX/include
install -D ./build/include/magma_config.h $PREFIX/include/magma_config.h
install -D ./build/lib/pkgconfig/magma.pc $PREFIX/lib/pkgconfig/magma.pc
