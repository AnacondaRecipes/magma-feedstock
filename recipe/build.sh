#!/bin/bash

export CMAKE_LIBRARY_PATH=$PREFIX/lib:$PREFIX/include:$CMAKE_LIBRARY_PATH
export CMAKE_PREFIX_PATH=$PREFIX
export PATH=$PREFIX/bin:/usr/local/cuda-${cudatoolkit}/bin:$PATH
export MKLROOT=$PREFIX/lib

mkdir build
cd build
# Use explicit compute capabilities compatible with CUDA 12.x (min: compute_35)
# 35,37: Kepler (K40+), 50,52,53: Maxwell, 60,61,62: Pascal, 70,72,75: Volta/Turing, 80,86,87: Ampere, 89,90: Ada/Hopper
cmake .. -DUSE_FORTRAN=OFF -DGPU_TARGET="35 50 60 70 75 80 86 89" -DMAGMA_ENABLE_CUDA=ON -DCMAKE_INSTALL_PREFIX=$PREFIX
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
