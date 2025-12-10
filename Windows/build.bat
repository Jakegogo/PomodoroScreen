@echo off
setlocal

rem 简单构建脚本，对应 README 中的构建步骤：
rem   cd Windows
rem   cmake -S . -B build
rem   cmake --build build --config Release
rem   ./build/PomodoroScreenWin.exe

cd /d "%~dp0"

echo [build] 配置 CMake 工程...
cmake -S . -B build
if errorlevel 1 goto :cmake_error

echo.
echo [build] 开始编译 (显示详细编译命令)...
cmake --build build --config Release --verbose
if errorlevel 1 goto :build_error

echo.
echo [build] 编译成功，启动程序...
echo.
.\build\PomodoroScreenWin.exe
goto :end

:cmake_error
echo.
echo [build] ❌ CMake 配置失败，详细错误信息已在上方输出。
echo [build] 如需更多信息，可查看 build\CMakeFiles\CMakeError.log
goto :end

:build_error
echo.
echo [build] ❌ 编译失败，上方已经显示 cl.exe / nmake 的完整错误输出。
echo [build] 可以滚动终端向上查看具体出错的源文件和行号。
goto :end

:end
echo.
pause
endlocal


