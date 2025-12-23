@echo off
setlocal EnableExtensions DisableDelayedExpansion

rem Simple build script (Windows):
rem   cd Windows
rem   build.bat
rem   build.bat --no-clean

cd /d "%~dp0"

rem Build options:
rem   build.bat              -> build with --clean-first (default)
rem   build.bat --no-clean   -> build without --clean-first
set "CLEAN_FIRST=1"
if /I "%~1"=="--no-clean" set "CLEAN_FIRST=0"
if /I "%~1"=="--no-clean-first" set "CLEAN_FIRST=0"

echo [build] Configuring CMake project...
cmake -S . -B build
if errorlevel 1 goto :cmake_error

echo.
if "%CLEAN_FIRST%"=="1" goto :build_clean_first
goto :build_no_clean_first

:build_clean_first
echo [build] Building (clean first, verbose)...
cmake --build build --config Release --verbose --clean-first
goto :build_done

:build_no_clean_first
echo [build] Building (no clean-first, verbose)...
cmake --build build --config Release --verbose
goto :build_done

:build_done
if errorlevel 1 goto :build_error

echo.
echo [build] Build succeeded, searching for executable and starting program...
echo.

set "EXE_PATH="
if exist ".\build\PomodoroScreenWin.exe" (
  set "EXE_PATH=.\build\PomodoroScreenWin.exe"
) else if exist ".\build\Release\PomodoroScreenWin.exe" (
  set "EXE_PATH=.\build\Release\PomodoroScreenWin.exe"
) else if exist ".\build\Debug\PomodoroScreenWin.exe" (
  set "EXE_PATH=.\build\Debug\PomodoroScreenWin.exe"
)

if defined EXE_PATH (
  echo [build] Run: %EXE_PATH%
  echo.
  %EXE_PATH%
) else (
  echo [build] WARNING: PomodoroScreenWin.exe not found, please check the build directory.
)
goto :end

:cmake_error
echo.
echo [build] CMake configuration FAILED, see errors above.
echo [build] For more details, check build\CMakeFiles\CMakeError.log
goto :end

:build_error
echo.
echo [build] Build FAILED, full cl.exe / nmake error output is shown above.
echo [build] Scroll up to find the exact source file and line number.
goto :end

:end
echo.
pause
endlocal


