@echo on

:: This step is required when building from raw source archive
:: make generate --jobs %CPU_COUNT%
:: if errorlevel 1 exit /b 1

:: Duplicate lists because of https://bitbucket.org/icl/magma/pull-requests/32
set "CUDA_ARCH_LIST=sm_60,sm_70,sm_80"
set "CUDAARCHS=60-virtual;70-virtual;80-virtual"

if "%cuda_compiler_version%"=="11.8" (
  set "CUDA_ARCH_LIST=%CUDA_ARCH_LIST%,sm_90"
  set "CUDAARCHS=%CUDAARCHS%;90-virtual"

) else if "%cuda_compiler_version:~0,3%"=="12." (
  set "CUDA_ARCH_LIST=%CUDA_ARCH_LIST%,sm_90"
  set "CUDAARCHS=%CUDAARCHS%;90-virtual"

) else (
  echo Unsupported CUDA version. Please update bld.bat
  exit /b 1
)

md build
cd build
if errorlevel 1 exit /b 1

:: Set MKLROOT and CMAKE_PREFIX_PATH for MKL detection
set "MKLROOT=%LIBRARY_PREFIX%"
set "CMAKE_PREFIX_PATH=%LIBRARY_PREFIX%;%CMAKE_PREFIX_PATH%"

:: Set BLA_VENDOR environment variable so CMake can find MKL
set "BLA_VENDOR=Intel10_64lp"

:: Explicitly set MKL library using the single-dynamic runtime (mkl_rt.lib)
:: This is what's provided by mkl-devel on Windows defaults channel
set "LAPACK_LIBRARIES=%LIBRARY_PREFIX%\lib\mkl_rt.lib"

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
  -DMAGMA_WITH_MKL:BOOL=ON ^
  -DMKLROOT=%MKLROOT% ^
  -DBLA_VENDOR=%BLA_VENDOR% ^
  -DLAPACK_LIBRARIES="%LAPACK_LIBRARIES%" ^
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
