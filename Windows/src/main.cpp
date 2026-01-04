#include <windows.h>
#include <conio.h>
#include <iostream>
#include <chrono>
#include <thread>
#include <objbase.h>


#include "PomodoroTimer.h"
#include "MultiScreenOverlayManagerWin32.h"
#include "BackgroundSettingsWin32.h"
#include "SettingsWindowWin32.h"
#include "TrayIconWin32.h"
#include "MainWindowWin32.h"

namespace {
    void EnablePerMonitorDpiAwareness() {
        // Root-cause fix for “UI looks blurry” on Windows:
        // If the process is not DPI-aware, Windows bitmap-scales the entire UI.
        // We opt into Per-Monitor V2 awareness early, before creating any windows.
#ifndef DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2
#define DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 ((DPI_AWARENESS_CONTEXT)-4)
#endif
#ifndef DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE
#define DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE ((DPI_AWARENESS_CONTEXT)-3)
#endif

        HMODULE user32 = GetModuleHandleW(L"user32.dll");
        if (user32) {
            using SetDpiAwarenessContextFn = BOOL(WINAPI*)(DPI_AWARENESS_CONTEXT);
            auto setCtx = reinterpret_cast<SetDpiAwarenessContextFn>(
                GetProcAddress(user32, "SetProcessDpiAwarenessContext"));
            if (setCtx) {
                if (setCtx(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)) {
                    return;
                }
                setCtx(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE);
                return;
            }

            using SetDpiAwareFn = BOOL(WINAPI*)();
            auto setOld = reinterpret_cast<SetDpiAwareFn>(GetProcAddress(user32, "SetProcessDPIAware"));
            if (setOld) {
                setOld();
            }
        }
    }
} // namespace

// NOTE:
// Windows 端临时前端：
// - 单线程主循环 + Win32 消息泵
// - 托盘图标显示当前状态 + 倒计时，点击时弹出自绘制弹窗
// - 在番茄结束进入休息期时，通过 MultiScreenOverlayManagerWin32 显示多屏遮罩
// - 按下 'c' 打开背景设置面板
int main() {
    using namespace std::chrono;
    using pomodoro::PomodoroTimer;
    using pomodoro::MultiScreenOverlayManagerWin32;
    using pomodoro::BackgroundSettingsWin32;
    using pomodoro::SettingsWindowWin32;
    using pomodoro::TrayIconWin32;

    EnablePerMonitorDpiAwareness();

    const HRESULT comHr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    const bool comInitialized = SUCCEEDED(comHr);

    // 获取当前进程实例句柄，用于创建 Win32 窗口
    HINSTANCE hInstance = GetModuleHandleW(nullptr);

    PomodoroTimer timer;
    MultiScreenOverlayManagerWin32 overlayManager(hInstance);

    // 加载遮罩背景配置（与 macOS 的背景设置逻辑对应），存放在用户配置目录
    BackgroundSettingsWin32 backgroundSettings;
    const std::wstring settingsPath = BackgroundSettingsWin32::DefaultConfigPath();
    backgroundSettings.loadFromFile(settingsPath);
    g_backgroundSettings = &backgroundSettings;

    // 当用户点击“取消休息”按钮或按下 ESC 关闭遮罩时：
    // - 隐藏所有遮罩（由 MultiScreenOverlayManagerWin32 完成）
    // - 立即开始下一轮番茄钟（跳过剩余休息时间）
    overlayManager.setOnDismissAllCallback([&timer]() {
        timer.start();
    });

    // 注册并创建隐藏主窗口（用于托盘消息分发）
    WNDCLASSEXW wc{};
    wc.cbSize = sizeof(wc);
    wc.style = CS_HREDRAW | CS_VREDRAW;
    wc.lpfnWndProc = MainWndProc;
    wc.hInstance = hInstance;
    wc.lpszClassName = kMainWindowClassName;
    RegisterClassExW(&wc);

    PomodoroTimer::Settings settings;
    settings.pomodoroMinutes = backgroundSettings.pomodoroMinutes();
    settings.autoStartNextPomodoroAfterRest = backgroundSettings.autoStartNextPomodoroAfterRest();
    timer.updateSettings(settings);

    // 让 MainWndProc（托盘打开设置窗口的路径）也能同步更新 timer 的设置
    g_pomodoroTimer = &timer;
    g_pomodoroTimerSettings = &settings;

    // 创建隐藏主窗口和托盘图标
    TrayIconWin32* trayIcon = nullptr;
    HWND mainHwnd = CreateWindowExW(
        0,
        kMainWindowClassName,
        L"PomodoroScreenMain",
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        100,
        100,
        nullptr,
        nullptr,
        hInstance,
        nullptr
    );

    if (mainHwnd) {
        trayIcon = new TrayIconWin32(hInstance, mainHwnd, timer);
        SetWindowLongPtrW(mainHwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(trayIcon));
    }

    timer.onTimeUpdate = [trayIcon, &timer, &overlayManager, &backgroundSettings](const std::string& text) {
        std::cout << "\rTime: " << text << "    " << std::flush;
        if (trayIcon) {
            bool isRest = timer.isInRestPeriod();
            bool isForced = false; // TODO: 暂未暴露强制休眠状态，可在 AutoRestartStateMachine 上增加只读接口
            bool isRunning = timer.isRunning();
            trayIcon->updateTime(text, isRest, isForced, isRunning);
        }

        // 休息结束后：根据设置决定是否自动隐藏遮罩层并进入下一轮番茄
        if (backgroundSettings.autoStartNextPomodoroAfterRest()) {
            if (!timer.isInRestPeriod() && !timer.isRestTimerRunning()) {
                if (overlayManager.hasOverlays()) {
                    overlayManager.hideAllOverlays();
                }
            }
        }
    };

    // 工作阶段结束 -> 进入休息期时，在所有屏幕上展示遮罩层
    timer.onTimerFinished = [&overlayManager]() {
        std::cout << "\n[Pomodoro Finished] -> Enter rest period, show overlay on all screens\n";
        overlayManager.showOverlaysOnAllScreens();
    };

    // 熬夜强制睡眠结束时，隐藏遮罩
    timer.onForcedSleepEndedCallback = [&overlayManager]() {
        std::cout << "\n[Forced Sleep Ended] -> Hide stay-up overlay\n";
        overlayManager.hideAllOverlays();
    };

    std::cout << "PomodoroScreen Windows (console + overlay + tray icon)\n";
    std::cout << "Commands: s=start, p=pause, r=resume, c=config, q=quit\n";

    bool running = true;

    // 记录上一秒 tick 的时间，用于每秒调用一次 timer.tickOneSecond()
    auto lastTick = steady_clock::now();

    while (running) {
        // 处理 Win32 消息，使遮罩窗口能够正常绘制和响应输入
        MSG msg;
        while (PeekMessageW(&msg, nullptr, 0, 0, PM_REMOVE)) {
            if (msg.message == WM_QUIT) {
                running = false;
                break;
            }
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
        }

        if (!running) {
            break;
        }

        // 处理控制台按键（非阻塞）
        if (_kbhit()) {
            int ch = _getch();
            if (ch == 'q' || ch == 'Q') {
                running = false;
            } else if (ch == 's' || ch == 'S') {
                timer.start();
            } else if (ch == 'p' || ch == 'P') {
                timer.pause();
            } else if (ch == 'r' || ch == 'R') {
                timer.resume();
            } else if (ch == 'c' || ch == 'C') {
                if (!g_settingsWindow) {
                    g_settingsWindow = new SettingsWindowWin32(hInstance, backgroundSettings);
                    g_settingsWindow->setPomodoroMinutesChangedHandler([&timer, &settings](int minutes) {
                        settings.pomodoroMinutes = minutes;
                        timer.updateSettings(settings);
                    });
                    g_settingsWindow->setAutoStartNextPomodoroAfterRestChangedHandler([&timer, &settings](bool enabled) {
                        settings.autoStartNextPomodoroAfterRest = enabled;
                        timer.updateSettings(settings);
                    });
                }
                g_settingsWindow->show();
            }
        }

        // 每 1 秒调用一次 tickOneSecond，驱动番茄计时逻辑
        auto now = steady_clock::now();
        if (duration_cast<seconds>(now - lastTick).count() >= 1) {
            timer.tickOneSecond();
            lastTick = now;
        }

        // 避免空转占用 100% CPU
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }

    // 退出前确保遮罩隐藏并持久化背景设置
    overlayManager.hideAllOverlays();
    backgroundSettings.saveToFile(settingsPath);

    delete trayIcon;
    DestroyWindow(mainHwnd);
    delete g_settingsWindow;
    g_settingsWindow = nullptr;

    std::cout << "\nExiting...\n";
    if (comInitialized) {
        CoUninitialize();
    }
    return 0;
}
