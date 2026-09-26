@echo off
setlocal
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
for /f "usebackq tokens=*" %%i in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSINSTALL=%%i"
if not defined VSINSTALL (
    echo Visual Studio C++ tools were not found.
    exit /b 1
)
call "%VSINSTALL%\VC\Auxiliary\Build\vcvars64.bat"
if errorlevel 1 exit /b %errorlevel%
set "PATH=%VSINSTALL%\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja;%PATH%"
cd /d "%~dp0.."
cmake -S . -B build-cuda -G Ninja -DCMAKE_BUILD_TYPE=Release -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=120a -DGGML_NATIVE=ON -DGGML_VULKAN=OFF -DGGML_SYCL=OFF -DGGML_RPC=OFF -DGGML_CUDA_NCCL=OFF -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_BUILD_TESTS=ON
if errorlevel 1 exit /b %errorlevel%
cmake --build build-cuda --config Release --parallel 12 --target llama-server llama-cli llama-bench test-backend-ops test-arg-parser
exit /b %errorlevel%
