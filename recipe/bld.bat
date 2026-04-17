@echo on

:: Git tag archives need generated precision sources (Makefile), same as Unix build.sh.
:: Requires GNU Make, Perl, and Python on PATH (not always present on Windows builders).
pushd %SRC_DIR%
(
echo BACKEND = cuda
echo FORT = true
echo GPU_TARGET = Ampere
) > make.inc

make generate --jobs %CPU_COUNT%
if errorlevel 1 exit /b 1
del make.inc
popd

:: Duplicate lists because of https://bitbucket.org/icl/magma/pull-requests/32
set "CUDA_ARCH_LIST=sm_60,sm_70,sm_80"
set "CUDAARCHS=60-virtual;70-virtual;80-virtual"

if "%cuda_compiler_version%"=="11.8" (
  set "CUDA_ARCH_LIST=%CUDA_ARCH_LIST%,sm_90"
  set "CUDAARCHS=%CUDAARCHS%;90-virtual"

) else if "%cuda_compiler_version:~0,3%"=="12." (
  set "CUDA_ARCH_LIST=%CUDA_ARCH_LIST%,sm_90"
  set "CUDAARCHS=%CUDAARCHS%;90-virtual"

) else if "%cuda_compiler_version:~0,3%"=="13." (
  REM CUDA 13 drops support for sm_60 and sm_70.
  REM We overwrite the list (do not use %CUDA_ARCH_LIST% prefix)
  REM Adds sm_100 (Blackwell Data Center) and sm_120 (Blackwell Consumer)
  set "CUDA_ARCH_LIST=sm_80,sm_90,sm_100,sm_120"
  set "CUDAARCHS=80-virtual;90-virtual;100-virtual;120-virtual"

) else (
  echo Unsupported CUDA version. Please update bld.bat
  exit /b 1
)

md build
cd build
if errorlevel 1 exit /b 1

set "CMAKE_PREFIX_PATH=%LIBRARY_PREFIX%;%CMAKE_PREFIX_PATH%"

if "%blas_impl%"=="openblas" (
    set "BLAS_CONFIG=-DBLA_VENDOR=OpenBLAS -DLAPACK_LIBRARIES=%LIBRARY_PREFIX%\lib\openblas.lib"
) else if "%blas_impl%"=="mkl" (
    set "BLAS_CONFIG=-DBLA_VENDOR=Intel10_64lp -DMAGMA_WITH_MKL:BOOL=ON -DMKLROOT=%LIBRARY_PREFIX% -DLAPACK_LIBRARIES=%LIBRARY_PREFIX%\lib\mkl_rt.lib"
) else (
    echo ERROR: blas_impl must be openblas or mkl, got "%blas_impl%"
    exit /b 1
)

:: Must add --use-local-env to NVCC_FLAGS otherwise NVCC autoconfigs the host
:: compiler to cl.exe instead of the full path. MSVC does not accept a
:: C++11 standard argument, and defaults to C++14
:: https://learn.microsoft.com/en-us/cpp/overview/visual-cpp-language-conformance?view=msvc-160
:: https://learn.microsoft.com/en-us/cpp/build/reference/std-specify-language-standard-version?view=msvc-160
cmake %SRC_DIR% ^
  -G "Ninja" ^
  -DCMAKE_WINDOWS_EXPORT_ALL_SYMBOLS:BOOL=ON ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DCMAKE_PREFIX_PATH=%LIBRARY_PREFIX% ^
  -DGPU_TARGET="%CUDA_ARCH_LIST%" ^
  -DMAGMA_ENABLE_CUDA:BOOL=ON ^
  -DUSE_FORTRAN:BOOL=OFF ^
  %BLAS_CONFIG% ^
  -DCMAKE_CXX_STANDARD=17 ^
  -DCMAKE_CUDA_FLAGS="--use-local-env -Xfatbin -compress-all -Wno-deprecated-gpu-targets" ^
  -DCMAKE_CUDA_SEPARABLE_COMPILATION:BOOL=OFF
if errorlevel 1 exit /b 1

cmake --build . ^
    --config Release ^
    --parallel %CPU_COUNT% ^
    --target magma magma_sparse ^
    --verbose
if errorlevel 1 exit /b 1

copy /Y .\lib\magma.lib %LIBRARY_PREFIX%\lib\magma.lib
if errorlevel 1 exit /b 1
copy /Y .\magma.dll %LIBRARY_PREFIX%\bin\magma.dll
if errorlevel 1 exit /b 1
copy /Y .\lib\magma_sparse.lib %LIBRARY_PREFIX%\lib\magma_sparse.lib
if errorlevel 1 exit /b 1
copy /Y .\magma_sparse.dll %LIBRARY_PREFIX%\bin\magma_sparse.dll
if errorlevel 1 exit /b 1

cd ..

if not exist %LIBRARY_PREFIX%\include md %LIBRARY_PREFIX%\include
xcopy /s /k /y /i .\include\*.h %LIBRARY_PREFIX%\include
if errorlevel 1 exit /b 1
xcopy /s /k /y /i .\sparse\include\*.h %LIBRARY_PREFIX%\include
if errorlevel 1 exit /b 1
copy /Y .\build\include\magma_config.h %LIBRARY_PREFIX%\include\magma_config.h
if errorlevel 1 exit /b 1
if not exist %LIBRARY_PREFIX%\lib\pkgconfig md %LIBRARY_PREFIX%\lib\pkgconfig
copy /Y .\build\lib\pkgconfig\magma.pc %LIBRARY_PREFIX%\lib\pkgconfig\magma.pc
if errorlevel 1 exit /b 1
