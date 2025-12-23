#pragma once

#include <windows.h>
#include <string>

#include "PomodoroTimer.h"
#include "TrayPopupWindowWin32.h"

namespace pomodoro {

    enum class TrayIconState {
        Work,
        Rest,
        ForcedSleep
    };

    // 托盘图标管理：负责创建/更新托盘图标，响应点击并显示弹窗
    class TrayIconWin32 {
    public:
        TrayIconWin32(HINSTANCE hInstance, HWND messageHwnd, PomodoroTimer& timer);
        ~TrayIconWin32();

        // 更新时间与状态，由 PomodoroTimer 的回调驱动
        void updateTime(const std::string& timeText, bool isRest, bool isForcedSleep, bool isRunning);

        // 处理来自托盘的回调消息
        void handleTrayMessage(WPARAM wParam, LPARAM lParam);

        // 处理主窗口转发的定时器消息（用于 hover 弹窗）
        void handleTimer(UINT_PTR timerId);

    private:
        void initNotifyIcon();
        void updateIcon(TrayIconState state, bool isRunning);
        void togglePopup();
        void showPopupIfNeeded();
        void hidePopupIfNeeded();

        HICON createStateIcon(TrayIconState state);

        HINSTANCE hInstance_{ nullptr };
        HWND messageHwnd_{ nullptr };
        PomodoroTimer& timer_;

        NOTIFYICONDATAW nid_{};
        HICON workIcon_{ nullptr };
        HICON restIcon_{ nullptr };
        HICON forcedIcon_{ nullptr };

        TrayPopupWindowWin32 popup_;

        std::wstring lastTimeText_;
        TrayIconState lastState_{ TrayIconState::Work };
        bool lastRunning_{ false };

        // hover 弹窗逻辑
        static constexpr UINT_PTR kHoverTimerId = 9001;
        DWORD lastMouseMoveTick_{ 0 };
        DWORD hoverStartTick_{ 0 };
        bool hoveringIcon_{ false };
        bool hasLastTrayCursorPos_{ false };
        POINT lastTrayCursorPos_{};
        bool pinnedByClick_{ false };
    };

} // namespace pomodoro



