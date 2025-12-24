#include "PomodoroTimer.h"

#include <sstream>
#include <iomanip>

namespace pomodoro {

    PomodoroTimer::PomodoroTimer()
        : stateMachine_(AutoRestartSettings{}) {
        // 默认设置，可被 updateSettings 覆盖
        Settings s;
        updateSettings(s);
    }

    void PomodoroTimer::updateSettings(const Settings& s) {
        settings_ = s;

        pomodoroSeconds_ = s.pomodoroMinutes * 60;
        breakSeconds_ = s.breakMinutes * 60;
        longBreakSeconds_ = s.longBreakMinutes * 60;

        meetingMode_ = s.meetingMode;

        AutoRestartSettings machineSettings;
        machineSettings.idleEnabled = s.idleRestartEnabled;
        machineSettings.idleActionIsRestart = s.idleActionIsRestart;
        machineSettings.screenLockEnabled = s.screenLockRestartEnabled;
        machineSettings.screenLockActionIsRestart = s.screenLockActionIsRestart;
        machineSettings.screensaverEnabled = s.screensaverRestartEnabled;
        machineSettings.screensaverActionIsRestart = s.screensaverActionIsRestart;
        machineSettings.stayUpLimitEnabled = s.stayUpLimitEnabled;
        machineSettings.stayUpLimitHour = s.stayUpLimitHour;
        machineSettings.stayUpLimitMinute = s.stayUpLimitMinute;

        stateMachine_.updateSettings(machineSettings);
    }

    void PomodoroTimer::tickOneSecond() {
        if (!isRunning()) return;

        if (remainingSeconds_ > 0) {
            --remainingSeconds_;
            updateTimeDisplay();
            return;
        }

        handlePhaseFinished();
    }

    void PomodoroTimer::finishNow() {
        // Force-finish regardless of remaining seconds; preserve "phase finished" logic.
        remainingSeconds_ = 0;
        handlePhaseFinished();
    }

    void PomodoroTimer::start() {
        // 如果处于熬夜强制睡眠，则只触发遮罩，由 UI 层处理
        if (stateMachine_.isInStayUpTime()) {
            onForcedSleepTriggered();
            return;
        }

        remainingSeconds_ = pomodoroSeconds_;
        stateMachine_.setTimerType(TimerType::Pomodoro);
        stateMachine_.processEvent(AutoRestartEvent::TimerStarted);
        updateTimeDisplay();
    }

    void PomodoroTimer::stop() {
        stateMachine_.processEvent(AutoRestartEvent::TimerStopped);
        updateTimeDisplay();
    }

    void PomodoroTimer::pause() {
        if (!isRunning()) return;
        stateMachine_.processEvent(AutoRestartEvent::TimerPaused);
        updateTimeDisplay();
    }

    void PomodoroTimer::resume() {
        // 仅在状态机认为处于“暂停”状态时才允许恢复
        if (!stateMachine_.isInPausedState()) return;

        // 如果已经走到 0 秒，再次点击“启动”视为重新开始一轮番茄
        if (remainingSeconds_ <= 0) {
            remainingSeconds_ = pomodoroSeconds_;
            updateTimeDisplay();
            return;
        }

        // 恢复时让状态机重新进入 TimerRunning 状态，不改变剩余时间
        // 这里复用 TimerStarted 事件，只触发状态迁移，不需要额外动作
        auto action = stateMachine_.processEvent(AutoRestartEvent::TimerStarted);
        handleAutoRestartAction(action);
    }

    bool PomodoroTimer::isRunning() const {
        return stateMachine_.isInRunningState();
    }

    bool PomodoroTimer::isPausedState() const {
        return stateMachine_.isInPausedState();
    }

    bool PomodoroTimer::canResume() const {
        return isPausedState() || (remainingSeconds_ > 0 && remainingSeconds_ < totalCurrentSeconds());
    }

    bool PomodoroTimer::isInRestPeriod() const {
        return stateMachine_.isInRestPeriod();
    }

    bool PomodoroTimer::isRestTimerRunning() const {
        return stateMachine_.isRestTimerRunning();
    }

    void PomodoroTimer::onIdleTimeExceeded() {
        auto action = stateMachine_.processEvent(AutoRestartEvent::IdleTimeExceeded);
        handleAutoRestartAction(action);
    }

    void PomodoroTimer::onUserActivity() {
        auto action = stateMachine_.processEvent(AutoRestartEvent::UserActivityDetected);
        handleAutoRestartAction(action);
    }

    void PomodoroTimer::onScreenLocked() {
        auto action = stateMachine_.processEvent(AutoRestartEvent::ScreenLocked);
        handleAutoRestartAction(action);
    }

    void PomodoroTimer::onScreenUnlocked() {
        auto action = stateMachine_.processEvent(AutoRestartEvent::ScreenUnlocked);
        handleAutoRestartAction(action);
    }

    void PomodoroTimer::onScreensaverStarted() {
        auto action = stateMachine_.processEvent(AutoRestartEvent::ScreensaverStarted);
        handleAutoRestartAction(action);
    }

    void PomodoroTimer::onScreensaverStopped() {
        stateMachine_.markScreensaverResumedNow();
        auto action = stateMachine_.processEvent(AutoRestartEvent::ScreensaverStopped);
        handleAutoRestartAction(action);
    }

    void PomodoroTimer::onForcedSleepTriggered() {
        stateMachine_.setStayUpTime(true);
        auto action = stateMachine_.processEvent(AutoRestartEvent::ForcedSleepTriggered);
        handleAutoRestartAction(action);
    }

    void PomodoroTimer::onForcedSleepEnded() {
        stateMachine_.setStayUpTime(false);
        auto action = stateMachine_.processEvent(AutoRestartEvent::ForcedSleepEnded);
        handleAutoRestartAction(action);
        if (onForcedSleepEndedCallback) {
            onForcedSleepEndedCallback();
        }
    }

    void PomodoroTimer::handleAutoRestartAction(AutoRestartAction action) {
        using A = AutoRestartAction;
        switch (action) {
        case A::None:
            break;
        case A::PauseTimer:
            // 对于简单实现，只标记为暂停状态，由 stateMachine 内部状态表示
            break;
        case A::ResumeTimer:
            // 状态机已切回运行状态，这里仅更新显示
            updateTimeDisplay();
            break;
        case A::RestartTimer:
            remainingSeconds_ = totalCurrentSeconds();
            updateTimeDisplay();
            break;
        case A::ShowRestOverlay:
            // 由上层 UI 根据 onTimerFinished 回调展示遮罩
            break;
        case A::StartNextPomodoro:
            remainingSeconds_ = pomodoroSeconds_;
            stateMachine_.setTimerType(TimerType::Pomodoro);
            updateTimeDisplay();
            break;
        case A::EnterForcedSleep:
            // 由上层 UI 展示强制睡眠遮罩
            break;
        case A::ExitForcedSleep:
            // 由上层隐藏遮罩
            break;
        }
    }

    void PomodoroTimer::updateTimeDisplay() {
        if (!onTimeUpdate) return;
        int total = remainingSeconds_;
        if (total < 0) total = 0;
        int minutes = total / 60;
        int seconds = total % 60;

        std::ostringstream oss;
        oss << std::setw(2) << std::setfill('0') << minutes
            << ":" << std::setw(2) << std::setfill('0') << seconds;

        onTimeUpdate(oss.str());
    }

    int PomodoroTimer::totalCurrentSeconds() const {
        if (!isInRestPeriod()) {
            return pomodoroSeconds_;
        }
        return isLongBreak_ ? longBreakSeconds_ : breakSeconds_;
    }

    void PomodoroTimer::handlePhaseFinished() {
        // 当前阶段结束
        if (!isInRestPeriod()) {
            // 工作阶段结束 -> 进入休息
            completedPomodoros_++;
            stateMachine_.processEvent(AutoRestartEvent::PomodoroFinished);
            if (onTimerFinished) {
                onTimerFinished();
            }

            // 根据 cycle 决定长休息还是短休息
            isLongBreak_ = (completedPomodoros_ > 0) &&
                (settings_.longBreakCycle > 0) &&
                (completedPomodoros_ % settings_.longBreakCycle == 0);

            remainingSeconds_ = isLongBreak_ ? longBreakSeconds_ : breakSeconds_;
            stateMachine_.setTimerType(isLongBreak_ ? TimerType::LongBreak : TimerType::ShortBreak);
            stateMachine_.processEvent(AutoRestartEvent::RestStarted);
        } else {
            // 休息阶段结束 -> 下一轮工作
            auto action = stateMachine_.processEvent(AutoRestartEvent::RestFinished);
            stateMachine_.setTimerType(TimerType::Pomodoro);
            remainingSeconds_ = pomodoroSeconds_;

            // RestFinished 在状态机中会切到 Idle，需要上层决定是否立即开始下一轮番茄。
            // Windows 端用设置项控制：开启时自动开始；关闭时等待用户（例如点击“取消休息”）触发 start。
            if (action == AutoRestartAction::StartNextPomodoro && settings_.autoStartNextPomodoroAfterRest) {
                start();
                return;
            }
        }

        updateTimeDisplay();
    }

} // namespace pomodoro


