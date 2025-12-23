#pragma once

// MultiScreenOverlayManagerWin32
// ------------------------------
// 参考 macOS 端的 `MultiScreenOverlayManager`：
// - 负责在所有物理屏幕上创建 / 显示 / 隐藏遮罩窗口
// - 单个屏幕的显示细节由 `OverlayWindowWin32` 处理
//
// 本实现使用 Win32 API 的 `EnumDisplayMonitors` 获取所有显示器，
// 并为每个显示器创建一个全屏的 OverlayWindowWin32。

#include <windows.h>
#include <vector>
#include <memory>
#include <functional>

#include "OverlayWindowWin32.h"

namespace pomodoro {

    class MultiScreenOverlayManagerWin32 {
    public:
        explicit MultiScreenOverlayManagerWin32(HINSTANCE hInstance);
        ~MultiScreenOverlayManagerWin32();

        // 在所有屏幕上显示遮罩层
        void showOverlaysOnAllScreens();

        // 隐藏所有遮罩层
        void hideAllOverlays();

        bool hasOverlays() const { return !overlays_.empty(); }

        // 当“取消休息”或 ESC 关闭任一遮罩时回调（用于进入下一轮番茄）
        void setOnDismissAllCallback(const std::function<void()>& cb) { onDismissAll_ = cb; }

    private:
        static BOOL CALLBACK MonitorEnumProc(HMONITOR hMonitor, HDC hdc, LPRECT lprcMonitor, LPARAM dwData);
        void createOverlayForRect(const RECT& rect);

    private:
        HINSTANCE hInstance_{ nullptr };
        std::vector<std::unique_ptr<OverlayWindowWin32>> overlays_;
        std::function<void()> onDismissAll_{};
    };

} // namespace pomodoro


