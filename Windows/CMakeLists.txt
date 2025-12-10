cmake_minimum_required(VERSION 3.16)

project(PomodoroScreenWin LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(PomodoroScreenWin
    src/main.cpp
    src/PomodoroTimer.h
    src/PomodoroTimer.cpp
    src/AutoRestartStateMachine.h
    src/AutoRestartStateMachine.cpp
    src/BackgroundSettingsWin32.h
    src/BackgroundSettingsWin32.cpp
    src/SettingsWindowWin32.h
    src/SettingsWindowWin32.cpp
    src/OverlayWindowWin32.h
    src/OverlayWindowWin32.cpp
    src/MultiScreenOverlayManagerWin32.h
    src/MultiScreenOverlayManagerWin32.cpp
)

if(MSVC)
    target_compile_options(PomodoroScreenWin PRIVATE /W4 /permissive-)
else()
    target_compile_options(PomodoroScreenWin PRIVATE -Wall -Wextra -Wpedantic)
endif()

target_link_libraries(PomodoroScreenWin PRIVATE Gdiplus)


