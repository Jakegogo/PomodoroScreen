#pragma once

// NOTE:
// This is a manual C++ port of the Swift `AutoRestartStateMachine` used in the macOS PomodoroScreen project.
// It keeps the same high‑level states, events and actions so that the core timing / auto‑restart logic
// can be reused on Windows without depending on Cocoa or other macOS frameworks.
//
// The goal here is *logic equivalence*, not a line‑by‑line translation. Some debug prints and
// macOS‑specific concerns are intentionally dropped or simplified. Platform integration (screen lock,
// screensaver, idle detection) should be implemented in a higher‑level Windows shell that calls into
// this state machine.

#include <chrono>

namespace pomodoro {

    enum class AutoRestartState {
        Idle,                   // 空闲状态，等待事件
        TimerRunning,           // 计时器运行中
        TimerPausedByUser,      // 因用户手动暂停
        TimerPausedByIdle,      // 因无操作而暂停
        TimerPausedBySystem,    // 因系统事件（锁屏、屏保）而暂停
        AwaitingRestart,        // 等待重新启动
        RestPeriod,             // 休息期间（等待用户开始休息或取消）
        RestTimerRunning,       // 休息计时器运行中
        RestTimerPausedByUser,  // 休息计时器因用户手动暂停
        RestTimerPausedBySystem,// 休息计时器因系统事件暂停
        ForcedSleep             // 强制睡眠状态（熬夜限制触发）
    };

    enum class AutoRestartEvent {
        TimerStarted,          // 计时器启动
        TimerStopped,          // 计时器停止
        TimerPaused,           // 计时器暂停（手动）
        IdleTimeExceeded,      // 无操作时间超过设定值
        UserActivityDetected,  // 检测到用户活动
        ScreenLocked,          // 屏幕锁定
        ScreenUnlocked,        // 屏幕解锁
        ScreensaverStarted,    // 屏保启动
        ScreensaverStopped,    // 屏保停止
        PomodoroFinished,      // 番茄钟完成
        RestStarted,           // 开始休息计时
        RestFinished,          // 休息完成
        RestCancelled,         // 休息被取消
        ForcedSleepTriggered,  // 强制睡眠触发（熬夜时间到达）
        ForcedSleepEnded       // 强制睡眠结束（用户取消或时间过了）
    };

    enum class AutoRestartAction {
        None,              // 无动作
        PauseTimer,        // 暂停计时器
        ResumeTimer,       // 恢复计时器
        RestartTimer,      // 重新开始计时器
        ShowRestOverlay,   // 显示休息遮罩（由上层 UI 来实现）
        StartNextPomodoro, // 开始下一个番茄钟
        EnterForcedSleep,  // 进入强制睡眠状态
        ExitForcedSleep    // 退出强制睡眠状态
    };

    enum class TimerType {
        Pomodoro,   // 番茄钟计时
        ShortBreak, // 短休息
        LongBreak   // 长休息
    };

    struct AutoRestartSettings {
        bool idleEnabled{ false };
        bool idleActionIsRestart{ true };
        bool screenLockEnabled{ false };
        bool screenLockActionIsRestart{ true };
        bool screensaverEnabled{ false };
        bool screensaverActionIsRestart{ true };

        // 熬夜限制设置
        bool stayUpLimitEnabled{ false };
        int  stayUpLimitHour{ 23 };    // 限制小时（21-1）
        int  stayUpLimitMinute{ 0 };   // 限制分钟（0, 15, 30, 45）
    };

    class AutoRestartStateMachine {
    public:
        using Clock = std::chrono::steady_clock;

        explicit AutoRestartStateMachine(const AutoRestartSettings& settings);

        void updateSettings(const AutoRestartSettings& settings);

        AutoRestartState getCurrentState() const noexcept;
        TimerType getCurrentTimerType() const noexcept;
        void setTimerType(TimerType type) noexcept;

        bool isInRestPeriod() const noexcept;
        bool isRestTimerRunning() const noexcept;
        bool isInForcedSleep() const noexcept;
        bool isInStayUpTime() const noexcept;
        bool isInPausedState() const noexcept;
        bool isInRunningState() const noexcept;

        // 主入口：根据事件返回需要执行的动作，由上层逻辑决定是否执行
        AutoRestartAction processEvent(AutoRestartEvent event);

        // 熬夜时间槽记录仅保留接口，具体持久化/统计由上层实现
        void markScreensaverResumedNow();
        void setStayUpTime(bool isStayUp);

    private:
        AutoRestartAction determineAction(AutoRestartEvent event, AutoRestartState state) const;
        AutoRestartState determineNewState(AutoRestartEvent event, AutoRestartState state) const;

        bool wasRecentlyResumedByScreensaver() const;

    private:
        AutoRestartState currentState_{ AutoRestartState::Idle };
        AutoRestartSettings settings_{};
        TimerType currentTimerType_{ TimerType::Pomodoro };

        bool isStayUpTime_{ false };
        Clock::time_point lastScreensaverResumeTime_{};
        bool hasScreensaverResumeTime_{ false };
    };

} // namespace pomodoro


