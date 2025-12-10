#include "AutoRestartStateMachine.h"

namespace pomodoro {

    AutoRestartStateMachine::AutoRestartStateMachine(const AutoRestartSettings& settings)
        : settings_(settings) {}

    void AutoRestartStateMachine::updateSettings(const AutoRestartSettings& settings) {
        settings_ = settings;
    }

    AutoRestartState AutoRestartStateMachine::getCurrentState() const noexcept {
        return currentState_;
    }

    TimerType AutoRestartStateMachine::getCurrentTimerType() const noexcept {
        return currentTimerType_;
    }

    void AutoRestartStateMachine::setTimerType(TimerType type) noexcept {
        currentTimerType_ = type;
    }

    bool AutoRestartStateMachine::isInRestPeriod() const noexcept {
        switch (currentState_) {
        case AutoRestartState::RestPeriod:
        case AutoRestartState::RestTimerRunning:
        case AutoRestartState::RestTimerPausedBySystem:
        case AutoRestartState::RestTimerPausedByUser:
            return true;
        default:
            return false;
        }
    }

    bool AutoRestartStateMachine::isRestTimerRunning() const noexcept {
        return currentState_ == AutoRestartState::RestTimerRunning;
    }

    bool AutoRestartStateMachine::isInForcedSleep() const noexcept {
        return currentState_ == AutoRestartState::ForcedSleep;
    }

    bool AutoRestartStateMachine::isInStayUpTime() const noexcept {
        return isStayUpTime_;
    }

    bool AutoRestartStateMachine::isInPausedState() const noexcept {
        switch (currentState_) {
        case AutoRestartState::TimerPausedByUser:
        case AutoRestartState::TimerPausedByIdle:
        case AutoRestartState::TimerPausedBySystem:
        case AutoRestartState::RestTimerPausedByUser:
        case AutoRestartState::RestTimerPausedBySystem:
            return true;
        default:
            return false;
        }
    }

    bool AutoRestartStateMachine::isInRunningState() const noexcept {
        switch (currentState_) {
        case AutoRestartState::TimerRunning:
        case AutoRestartState::RestTimerRunning:
            return true;
        default:
            return false;
        }
    }

    AutoRestartAction AutoRestartStateMachine::processEvent(AutoRestartEvent event) {
        const auto action = determineAction(event, currentState_);
        const auto newState = determineNewState(event, currentState_);
        currentState_ = newState;
        return action;
    }

    void AutoRestartStateMachine::markScreensaverResumedNow() {
        lastScreensaverResumeTime_ = Clock::now();
        hasScreensaverResumeTime_ = true;
    }

    void AutoRestartStateMachine::setStayUpTime(bool isStayUp) {
        isStayUpTime_ = isStayUp;
    }

    bool AutoRestartStateMachine::wasRecentlyResumedByScreensaver() const {
        if (!hasScreensaverResumeTime_) return false;
        const auto now = Clock::now();
        const auto diff = std::chrono::duration_cast<std::chrono::milliseconds>(now - lastScreensaverResumeTime_);
        return diff.count() < 1000; // 1 秒内视为刚刚恢复
    }

    AutoRestartAction AutoRestartStateMachine::determineAction(AutoRestartEvent event, AutoRestartState state) const {
        using S = AutoRestartState;
        using E = AutoRestartEvent;
        using A = AutoRestartAction;

        switch (event) {
        case E::TimerStarted:
        case E::TimerStopped:
        case E::TimerPaused:
            return A::None;

        case E::IdleTimeExceeded:
            if (state == S::TimerRunning && settings_.idleEnabled) {
                return A::PauseTimer;
            }
            return A::None;

        case E::UserActivityDetected:
            if (!settings_.idleEnabled) {
                // 其他所有状态都忽略
                return A::None;
            }
            if (state == S::TimerPausedByIdle) {
                return settings_.idleActionIsRestart ? A::RestartTimer : A::ResumeTimer;
            }
            if (state == S::TimerPausedBySystem || state == S::ForcedSleep) {
                // 系统事件暂停或强制睡眠时，用户活动不触发动作
                return A::None;
            }
            return A::None;

        case E::ScreenLocked:
            if (!settings_.screenLockEnabled) return A::None;
            if (state == S::TimerRunning || state == S::RestTimerRunning) {
                return settings_.screenLockActionIsRestart ? A::None : A::PauseTimer;
            }
            return A::None;

        case E::ScreenUnlocked:
            if (!settings_.screenLockEnabled) return A::None;
            if (state == S::TimerPausedBySystem) {
                if (wasRecentlyResumedByScreensaver()) {
                    return A::None;
                }
                return settings_.screenLockActionIsRestart ? A::RestartTimer : A::ResumeTimer;
            }
            if (state == S::RestTimerPausedBySystem) {
                if (wasRecentlyResumedByScreensaver()) {
                    return A::None;
                }
                return A::ResumeTimer;
            }
            if (state == S::TimerRunning) {
                if (wasRecentlyResumedByScreensaver()) {
                    return A::None;
                }
                return settings_.screenLockActionIsRestart ? A::RestartTimer : A::None;
            }
            if (state == S::ForcedSleep) {
                if (!isInStayUpTime()) {
                    return A::ExitForcedSleep;
                }
                return A::None;
            }
            return A::None;

        case E::ScreensaverStarted:
            if (!settings_.screensaverEnabled) return A::None;
            if (state == S::TimerRunning || state == S::RestTimerRunning) {
                return settings_.screensaverActionIsRestart ? A::None : A::PauseTimer;
            }
            return A::None;

        case E::ScreensaverStopped:
            if (!settings_.screensaverEnabled) return A::None;
            if (state == S::TimerPausedBySystem || state == S::RestTimerPausedBySystem) {
                // 屏保停止后，根据配置选择恢复或重启
                if (state == S::RestTimerPausedBySystem) {
                    // 休息期间解屏，一律恢复休息计时
                    return A::ResumeTimer;
                }
                return settings_.screensaverActionIsRestart ? A::RestartTimer : A::ResumeTimer;
            }
            return A::None;

        case E::PomodoroFinished:
            // 由上层触发休息 overlay 和下一轮番茄钟
            return A::ShowRestOverlay;

        case E::RestStarted:
            return A::None;

        case E::RestFinished:
            // 休息完成，开始下一个番茄钟
            return A::StartNextPomodoro;

        case E::RestCancelled:
            // 直接回到空闲或计时状态由状态机状态转换决定
            return A::None;

        case E::ForcedSleepTriggered:
            if (settings_.stayUpLimitEnabled) {
                return A::EnterForcedSleep;
            }
            return A::None;

        case E::ForcedSleepEnded:
            if (state == S::ForcedSleep) {
                return A::ExitForcedSleep;
            }
            return A::None;
        }

        return A::None;
    }

    AutoRestartState AutoRestartStateMachine::determineNewState(AutoRestartEvent event, AutoRestartState state) const {
        using S = AutoRestartState;
        using E = AutoRestartEvent;

        switch (event) {
        case E::TimerStarted:
            return S::TimerRunning;
        case E::TimerStopped:
            return S::Idle;
        case E::TimerPaused:
            return S::TimerPausedByUser;

        case E::IdleTimeExceeded:
            if (state == S::TimerRunning && settings_.idleEnabled) {
                return S::TimerPausedByIdle;
            }
            return state;

        case E::UserActivityDetected:
            if (!settings_.idleEnabled) return state;
            if (state == S::TimerPausedByIdle) {
                return settings_.idleActionIsRestart ? S::TimerRunning : S::TimerRunning;
            }
            return state;

        case E::ScreenLocked:
            if (!settings_.screenLockEnabled) return state;
            if (state == S::TimerRunning || state == S::RestTimerRunning) {
                return S::TimerPausedBySystem;
            }
            return state;

        case E::ScreenUnlocked:
            if (!settings_.screenLockEnabled) return state;
            if (state == S::TimerPausedBySystem) {
                return S::TimerRunning;
            }
            if (state == S::RestTimerPausedBySystem) {
                return S::RestTimerRunning;
            }
            if (state == S::ForcedSleep && !isInStayUpTime()) {
                return S::Idle;
            }
            return state;

        case E::ScreensaverStarted:
            if (!settings_.screensaverEnabled) return state;
            if (state == S::TimerRunning || state == S::RestTimerRunning) {
                return S::TimerPausedBySystem;
            }
            return state;

        case E::ScreensaverStopped:
            if (!settings_.screensaverEnabled) return state;
            if (state == S::TimerPausedBySystem) {
                return S::TimerRunning;
            }
            if (state == S::RestTimerPausedBySystem) {
                return S::RestTimerRunning;
            }
            return state;

        case E::PomodoroFinished:
            // 进入休息前的中间状态，由上层决定是否开始休息计时
            return S::RestPeriod;

        case E::RestStarted:
            return S::RestTimerRunning;

        case E::RestFinished:
            // 休息结束，计入统计后进入空闲或重新开始番茄钟由上层决定
            return S::Idle;

        case E::RestCancelled:
            // 取消休息，返回空闲
            return S::Idle;

        case E::ForcedSleepTriggered:
            if (settings_.stayUpLimitEnabled) {
                return S::ForcedSleep;
            }
            return state;

        case E::ForcedSleepEnded:
            if (state == S::ForcedSleep) {
                return S::Idle;
            }
            return state;
        }
    }

} // namespace pomodoro


