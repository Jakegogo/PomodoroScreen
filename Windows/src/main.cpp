#include <windows.h>
#include <conio.h>
#include <iostream>
#include <chrono>
#include <thread>

#include "PomodoroTimer.h"
#include "MultiScreenOverlayManagerWin32.h"
#include "BackgroundSettingsWin32.h"
#include "SettingsWindowWin32.h"

// NOTE:
// Windows 端临时前端：
// - 单线程主循环 + Win32 消息泵
// - 在番茄结束进入休息期时，通过 MultiScreenOverlayManagerWin32 显示多屏遮罩
// - 遮罩窗口的点击 / 按键会触发关闭回调，隐藏所有遮罩
// - 按下 'c' 打开简单的设置面板，可添加图片 / 视频作为遮罩背景（配置暂未接入渲染逻辑）
int main() {
    using namespace std::chrono;
    using pomodoro::PomodoroTimer;
    using pomodoro::MultiScreenOverlayManagerWin32;
    using pomodoro::BackgroundSettingsWin32;
    using pomodoro::SettingsWindowWin32;

    // 获取当前进程实例句柄，用于创建 Win32 窗口
    HINSTANCE hInstance = GetModuleHandleW(nullptr);

    PomodoroTimer timer;
    MultiScreenOverlayManagerWin32 overlayManager(hInstance);

    // 加载遮罩背景配置（与 macOS 的背景设置逻辑对应），存放在用户配置目录
    BackgroundSettingsWin32 backgroundSettings;
    const std::wstring settingsPath = BackgroundSettingsWin32::DefaultConfigPath();
    backgroundSettings.loadFromFile(settingsPath);

    PomodoroTimer::Settings settings;
    settings.pomodoroMinutes = 1;  // 便于测试，设为 1 分钟
    settings.breakMinutes = 1;
    settings.longBreakMinutes = 2;
    settings.longBreakCycle = 2;
    timer.updateSettings(settings);

    timer.onTimeUpdate = [](const std::string& text) {
        std::cout << "\rTime: " << text << "    " << std::flush;
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

    std::cout << "PomodoroScreen Windows (console + overlay test)\n";
    std::cout << "Commands: s=start, p=pause, r=resume, c=config, q=quit\n";

    bool running = true;

    // 设置窗口（懒创建）
    SettingsWindowWin32* settingsWindow = nullptr;

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
                if (!settingsWindow) {
                    settingsWindow = new SettingsWindowWin32(hInstance, backgroundSettings);
                }
                settingsWindow->show();
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

    delete settingsWindow;

    std::cout << "\nExiting...\n";
    return 0;
}


