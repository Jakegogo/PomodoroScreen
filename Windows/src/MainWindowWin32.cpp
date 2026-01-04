#include "MainWindowWin32.h"
#include "BackgroundSettingsWin32.h"
#include "SettingsWindowWin32.h"
#include "TrayIconWin32.h"
#include "PomodoroTimer.h"

// 全局符号定义（原先位于 main.cpp 顶部的匿名命名空间中）
const wchar_t* kMainWindowClassName = L"PomodoroMainWindowClass";
pomodoro::BackgroundSettingsWin32* g_backgroundSettings = nullptr;
pomodoro::SettingsWindowWin32* g_settingsWindow = nullptr;
pomodoro::PomodoroTimer* g_pomodoroTimer = nullptr;
pomodoro::PomodoroTimer::Settings* g_pomodoroTimerSettings = nullptr;

// 主窗口窗口过程：负责托盘消息转发以及打开设置窗口
LRESULT CALLBACK MainWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    auto* tray = reinterpret_cast<pomodoro::TrayIconWin32*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    switch (msg) {
    case WM_CREATE: {
        auto* cs = reinterpret_cast<CREATESTRUCTW*>(lParam);
        if (cs && cs->lpCreateParams) {
            SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(cs->lpCreateParams));
        }
        return 0;
    }
    case WM_APP + 1: // 托盘图标回调
        if (tray) {
            tray->handleTrayMessage(wParam, lParam);
        }
        return 0;
    case WM_TIMER:
        if (tray) {
            tray->handleTimer(static_cast<UINT_PTR>(wParam));
        }
        return 0;
    case WM_APP + 2: // 来自托盘弹窗的“设置”按钮
        if (g_backgroundSettings) {
            if (!g_settingsWindow) {
                // 直接从当前进程获取实例句柄创建设置窗口
                g_settingsWindow = new pomodoro::SettingsWindowWin32(
                    GetModuleHandleW(nullptr),
                    *g_backgroundSettings
                );
            }

            // 关键：从托盘打开设置窗口时也要把设置变更同步到 PomodoroTimer，
            // 否则“重置”仍会用默认 25 分钟。
            if (g_pomodoroTimer && g_pomodoroTimerSettings) {
                g_settingsWindow->setPomodoroMinutesChangedHandler([](int minutes) {
                    g_pomodoroTimerSettings->pomodoroMinutes = minutes;
                    g_pomodoroTimer->updateSettings(*g_pomodoroTimerSettings);
                });
                g_settingsWindow->setBreakMinutesChangedHandler([](int minutes) {
                    g_pomodoroTimerSettings->breakMinutes = minutes;
                    g_pomodoroTimer->updateSettings(*g_pomodoroTimerSettings);
                });
                g_settingsWindow->setAutoStartNextPomodoroAfterRestChangedHandler([](bool enabled) {
                    g_pomodoroTimerSettings->autoStartNextPomodoroAfterRest = enabled;
                    g_pomodoroTimer->updateSettings(*g_pomodoroTimerSettings);
                });
            }
            g_settingsWindow->show();
        }
        return 0;
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    default:
        break;
    }
    return DefWindowProcW(hwnd, msg, wParam, lParam);
}
