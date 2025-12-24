#pragma once

#include <windows.h>
#include <string>
#include <functional>

namespace pomodoro {

    // 状态弹窗窗口：显示当前状态 + 倒计时 + 基本控制按钮（启动 / 暂停 / 重置）
    class TrayPopupWindowWin32 {
    public:
        TrayPopupWindowWin32();
        ~TrayPopupWindowWin32();

        bool create(HINSTANCE hInstance);

        void showNearCursor();
        void hide();
        bool isVisible() const { return hwnd_ != nullptr && IsWindowVisible(hwnd_) != FALSE; }

        void updateContent(const std::wstring& statusText, const std::wstring& timeText);

        // 同步当前运行状态，用于更新“启动/暂停”按钮文本
        void setRunningState(bool running);

        HWND hwnd() const { return hwnd_; }

        // 行为回调，由托盘管理类（TrayIconWin32）注入，转发给上层逻辑
        void setStartHandler(const std::function<void()>& handler) { onStartClicked_ = handler; }
        void setPauseHandler(const std::function<void()>& handler) { onPauseClicked_ = handler; }
        void setResetHandler(const std::function<void()>& handler) { onResetClicked_ = handler; }
        void setSettingsHandler(const std::function<void()>& handler) { onSettingsClicked_ = handler; }

        // 全局窗口过程需要从 RegisterClassExW 访问，因此放在 public 区域
        static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam);

    private:
        LRESULT handleMessage(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam);

        void paint();
        void applyDpiLayout(UINT dpi, const RECT* suggestedWindowRect);
        void renderLayered();
        void updateHitTestRects();
        bool hitTest(const RECT& rc, int x, int y) const;

        HINSTANCE hInstance_{ nullptr };
        HWND hwnd_{ nullptr };

        // Custom-drawn “buttons” (hit-test rects)
        RECT rcStart_{};
        RECT rcReset_{};
        RECT rcSettings_{};
        bool pressedStart_{ false };
        bool pressedReset_{ false };
        bool pressedSettings_{ false };

        std::wstring statusText_;
        std::wstring timeText_;

        // 当前是否处于运行状态（由外部计时器驱动同步）
        bool isRunning_{ false };

        // 调用方传入的行为处理函数
        std::function<void()> onStartClicked_;
        std::function<void()> onPauseClicked_;
        std::function<void()> onResetClicked_;
        std::function<void()> onSettingsClicked_;

        UINT dpi_{ 96 };
        SIZE windowSize_{ 0, 0 };
    };

} // namespace pomodoro



