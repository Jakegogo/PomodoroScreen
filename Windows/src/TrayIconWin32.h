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

    private:
        void initNotifyIcon();
        void updateIcon(TrayIconState state, bool isRunning);
        void togglePopup();

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
    };

} // namespace pomodoro



