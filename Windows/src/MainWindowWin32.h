#pragma once

#include <windows.h>

namespace pomodoro {
    class BackgroundSettingsWin32;
    class SettingsWindowWin32;
    class TrayIconWin32;
}

// 隐藏主窗口相关的全局符号和窗口过程声明
// 为了保持与现有逻辑一致，这里只做拆分，不改动行为

extern const wchar_t* kMainWindowClassName;
extern pomodoro::BackgroundSettingsWin32* g_backgroundSettings;
extern pomodoro::SettingsWindowWin32* g_settingsWindow;

// 主窗口窗口过程：负责托盘消息转发以及打开设置窗口
LRESULT CALLBACK MainWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam);
