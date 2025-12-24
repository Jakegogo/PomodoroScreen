#pragma once

// A platform-agnostic C++ port of the core Pomodoro timing logic from the Swift PomodoroTimer.
// This class intentionally contains no UI or platform APIs. A Windows shell (Win32/WinUI/Qt/etc.)
// should own one instance of PomodoroTimer and wire it to:
// - system timers / game loop
// - user input (start / stop / pause / resume)
// - screen lock / screensaver / idle events
//
// NOTE: This is a *minimal viable* port focused on:
// - countdown management
// - rest/long-rest scheduling
// - delegation to AutoRestartStateMachine for state
// Many advanced features from the Swift version (background files, detailed statistics, debug helpers)
// are intentionally omitted or marked TODO to keep the first Windows version small and reviewable.

#include <functional>
#include <chrono>
#include <string>

#include "AutoRestartStateMachine.h"

namespace pomodoro {

    class PomodoroTimer {
    public:
        using Seconds = std::chrono::seconds;

        struct Settings {
            int pomodoroMinutes{ 25 };
            int breakMinutes{ 3 };
            int longBreakCycle{ 4 };
            int longBreakMinutes{ 15 };

            // 休息结束后是否自动开始下一轮番茄钟。
            // 该开关与 Windows 端“休息结束后自动隐藏遮罩层…”设置保持一致。
            bool autoStartNextPomodoroAfterRest{ true };

            bool idleRestartEnabled{ false };
            int idleTimeMinutes{ 10 };
            bool idleActionIsRestart{ true };

            bool screenLockRestartEnabled{ false };
            bool screenLockActionIsRestart{ true };

            bool screensaverRestartEnabled{ false };
            bool screensaverActionIsRestart{ true };

            bool showCancelRestButton{ true };
            bool showLongBreakCancelButton{ true };
            bool accumulateRestTime{ false };

            bool stayUpLimitEnabled{ false };
            int stayUpLimitHour{ 23 };
            int stayUpLimitMinute{ 0 };

            bool meetingMode{ false };
        };

        // Callbacks (UI layer should subscribe)
        std::function<void()> onTimerFinished;                 // 工作计时完成
        std::function<void(const std::string&)> onTimeUpdate;  // 每秒更新时间显示
        std::function<void()> onForcedSleepEndedCallback;      // 强制睡眠结束回调

        PomodoroTimer();

        void updateSettings(const Settings& settings);

        void tickOneSecond(); // 上层每秒调用一次（或用真正的计时器回调）

        void start();
        void stop();
        void pause();
        void resume();

        bool isRunning() const;
        bool isPausedState() const;
        bool canResume() const;

        bool isInRestPeriod() const;
        bool isRestTimerRunning() const;
        bool isMeetingMode() const { return meetingMode_; }

        // System events that should be forwarded from Windows shell
        void onIdleTimeExceeded();
        void onUserActivity();
        void onScreenLocked();
        void onScreenUnlocked();
        void onScreensaverStarted();
        void onScreensaverStopped();

        // Forced sleep / stay-up logic (mirrors Swift behaviour at high level)
        void onForcedSleepTriggered();
        void onForcedSleepEnded();

        // Force-finish the current phase immediately.
        // Used by tray menu: "Complete Now" to end the current pomodoro and enter rest (show overlay).
        void finishNow();

    private:
        void handleAutoRestartAction(AutoRestartAction action);
        void updateTimeDisplay();
        int totalCurrentSeconds() const;
        void handlePhaseFinished();

    private:
        Settings settings_{};

        int remainingSeconds_{ 25 * 60 };
        int pomodoroSeconds_{ 25 * 60 };
        int breakSeconds_{ 3 * 60 };
        int longBreakSeconds_{ 5 * 60 };

        int completedPomodoros_{ 0 };
        bool isLongBreak_{ false };
        bool meetingMode_{ false };

        AutoRestartStateMachine stateMachine_;
    };

} // namespace pomodoro


