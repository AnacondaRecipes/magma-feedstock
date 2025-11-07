#!/bin/bash

export CMAKE_LIBRARY_PATH=$PREFIX/lib:$PREFIX/include:$CMAKE_LIBRARY_PATH
export CMAKE_PREFIX_PATH=$PREFIX
export PATH=$PREFIX/bin:/usr/local/cuda-${cudatoolkit}/bin:$PATH
export MKLROOT=$PREFIX/lib

mkdir build
cd build
# Use explicit compute capabilities compatible with CUDA 12.8 (min: sm_60 = Pascal)
# sm_60: Pascal, sm_70/75: Volta/Turing, sm_80/86: Ampere, sm_89: Ada, sm_90: Hopper
# Note: sm_60/sm_70 will be deprecated in future CUDA releases, but are still supported in 12.8
# Suppress deprecation warnings to clean up build logs
export CUDAFLAGS="-Wno-deprecated-gpu-targets"
export CXXFLAGS="${CXXFLAGS} -Wno-deprecated-declarations"
# Use medium code model to handle large binaries from multiple GPU architectures
# This prevents relocation overflow errors during linking
export CFLAGS="${CFLAGS} -mcmodel=medium"
export CXXFLAGS="${CXXFLAGS} -mcmodel=medium"
cmake .. -DUSE_FORTRAN=OFF -DGPU_TARGET="sm_60 sm_70 sm_75 sm_80 sm_86 sm_89 sm_90" -DMAGMA_ENABLE_CUDA=ON -DCMAKE_INSTALL_PREFIX=$PREFIX
make -j${CPU_COUNT} ${VERBOSE_AT}
make -j${CPU_COUNT} testing
make -j${CPU_COUNT} sparse-testing
cp testing/* ../testing/
cp sparse/testing/* ../sparse/testing/
cd ../testing
# These are manual builds for now. The test summary is written to conda-build output and the details are written to
# log files in the user's home directory.
python2 run_tests.py > ~/testing_output.txt
cd ../sparse/testing
python2 run_tests.py > ~/sparse_testing_output.txt
cd ../../build
make install
cd ..
