import Foundation

// MARK: - State Machine for Auto Restart Logic

/// 自动重新计时的状态
enum AutoRestartState {
    case idle                    // 空闲状态，等待事件
    case timerRunning           // 计时器运行中
    case timerPausedByUser      // 因用户手动暂停
    case timerPausedByIdle      // 因无操作而暂停
    case timerPausedBySystem    // 因系统事件（锁屏、屏保）而暂停
    case awaitingRestart        // 等待重新启动
    case restPeriod             // 休息期间（等待用户开始休息或取消）
    case restTimerRunning       // 休息计时器运行中
    case restTimerPausedByUser  // 休息计时器因用户手动暂停
    case restTimerPausedBySystem // 休息计时器因系统事件暂停
    case forcedSleep            // 强制睡眠状态（熬夜限制触发）
}

/// 自动重新计时的事件
enum AutoRestartEvent {
    case timerStarted           // 计时器启动
    case timerStopped           // 计时器停止
    case timerPaused            // 计时器暂停
    case idleTimeExceeded       // 无操作时间超过设定值
    case userActivityDetected   // 检测到用户活动
    case screenLocked           // 屏幕锁定
    case screenUnlocked         // 屏幕解锁
    case screensaverStarted     // 屏保启动
    case screensaverStopped     // 屏保停止
    case pomodoroFinished       // 番茄钟完成
    case restStarted            // 开始休息计时
    case restFinished           // 休息完成
    case restCancelled          // 休息被取消
    case forcedSleepTriggered   // 强制睡眠触发（熬夜时间到达）
    case forcedSleepEnded       // 强制睡眠结束（用户取消或时间过了）
}

/// 自动重新计时的动作
enum AutoRestartAction {
    case none               // 无动作
    case pauseTimer         // 暂停计时器
    case resumeTimer        // 恢复计时器
    case restartTimer       // 重新开始计时器
    case showRestOverlay    // 显示休息遮罩
    case startNextPomodoro  // 开始下一个番茄钟
    case enterForcedSleep   // 进入强制睡眠状态
    case exitForcedSleep    // 退出强制睡眠状态
}

/// 计时器类型枚举
enum TimerType {
    case pomodoro    // 番茄钟计时
    case shortBreak  // 短休息
    case longBreak   // 长休息
}

/// 自动重新计时状态机
class AutoRestartStateMachine {
    private var currentState: AutoRestartState = .idle
    private var settings: AutoRestartSettings
    private var lastScreensaverResumeTime: Date?
    private var currentTimerType: TimerType = .pomodoro // 当前计时器类型
    
    // 熬夜状态管理
    private var isStayUpTime: Bool = false // 当前是否处于熬夜时间
    private var stayUpMonitoringTimer: Timer? // 熬夜监控定时器
    
    struct AutoRestartSettings {
        let idleEnabled: Bool
        let idleActionIsRestart: Bool
        let screenLockEnabled: Bool
        let screenLockActionIsRestart: Bool
        let screensaverEnabled: Bool
        let screensaverActionIsRestart: Bool
        
        // 熬夜限制设置
        let stayUpLimitEnabled: Bool
        let stayUpLimitHour: Int // 限制小时（21-1）
        let stayUpLimitMinute: Int // 限制分钟（0, 15, 30, 45）
    }
    
    init(settings: AutoRestartSettings) {
        self.settings = settings
    }
    
    func updateSettings(_ newSettings: AutoRestartSettings) {
        self.settings = newSettings
    }
    
    func getCurrentState() -> AutoRestartState {
        return currentState
    }
    
    func getCurrentTimerType() -> TimerType {
        return currentTimerType
    }
    
    func setTimerType(_ type: TimerType) {
        currentTimerType = type
    }
    
    /// 检查是否处于休息期间
    func isInRestPeriod() -> Bool {
        switch currentState {
        case .restPeriod, .restTimerRunning, .restTimerPausedBySystem:
            return true
        default:
            return false
        }
    }
    
    /// 检查休息计时器是否正在运行
    func isRestTimerRunning() -> Bool {
        return currentState == .restTimerRunning
    }
    
    /// 检查是否处于强制睡眠状态
    func isInForcedSleep() -> Bool {
        return currentState == .forcedSleep
    }
    
    /// 检查当前是否处于熬夜时间
    func isInStayUpTime() -> Bool {
        return isStayUpTime
    }
    
    /// 检查是否处于暂停状态（包括手动暂停和系统暂停）
    func isInPausedState() -> Bool {
        switch currentState {
        case .timerPausedByUser, .timerPausedByIdle, .timerPausedBySystem, 
             .restTimerPausedByUser, .restTimerPausedBySystem:
            return true
        default:
            return false
        }
    }
    
    /// 检查是否处于运行状态（包括番茄钟运行和休息运行）
    func isInRunningState() -> Bool {
        switch currentState {
        case .timerRunning, .restTimerRunning:
            return true
        default:
            return false
        }
    }
    
    /// 检查是否刚刚通过屏保恢复（1秒内）
    private func wasRecentlyResumedByScreensaver() -> Bool {
        guard let lastResumeTime = lastScreensaverResumeTime else { return false }
        return Date().timeIntervalSince(lastResumeTime) < 1.0
    }
    
    func processEvent(_ event: AutoRestartEvent) -> AutoRestartAction {
        let action = determineAction(for: event, in: currentState)
        let newState = determineNewState(for: event, in: currentState)
        
        print("🔄 State Machine: \(currentState) + \(event) -> \(newState) (action: \(action))")
        
        currentState = newState
        return action
    }
    
    private func determineAction(for event: AutoRestartEvent, in state: AutoRestartState) -> AutoRestartAction {
        switch (event, state) {
        // 计时器状态变化
        case (.timerStarted, _):
            return .none
        case (.timerStopped, _):
            return .none
        case (.timerPaused, _):
            return .none
            
        // 无操作相关事件
        case (.idleTimeExceeded, .timerRunning):
            guard settings.idleEnabled else { 
                print("🔄 State Machine: 无操作功能未启用，忽略无操作超时")
                return .none 
            }
            print("🔄 State Machine: 无操作时间超时，暂停计时器")
            return .pauseTimer
        case (.userActivityDetected, .timerPausedByIdle):
            guard settings.idleEnabled else { 
                print("🔄 State Machine: 无操作功能未启用，忽略用户活动")
                return .none 
            }
            let action: AutoRestartAction = settings.idleActionIsRestart ? .restartTimer : .resumeTimer
            print("🔄 State Machine: 用户活动检测到，从无操作暂停状态执行动作: \(action)")
            return action
        case (.userActivityDetected, .timerPausedBySystem):
            // 系统事件暂停期间，用户活动不应该触发重新计时
            return .none
        case (.userActivityDetected, .forcedSleep):
            // 强制睡眠期间，用户活动不应该触发任何计时器动作
            print("🔄 State Machine: 强制睡眠期间，忽略用户活动")
            return .none
        case (.userActivityDetected, _):
            // 其他状态下的用户活动不做处理
            return .none
            
        // 锁屏相关事件
        case (.screenLocked, .timerRunning):
            guard settings.screenLockEnabled else { return .none }
            return settings.screenLockActionIsRestart ? .none : .pauseTimer
        case (.screenUnlocked, .timerPausedBySystem):
            guard settings.screenLockEnabled else { return .none }
            // 检查是否刚刚处理过屏保事件，如果是则忽略解锁事件
            if wasRecentlyResumedByScreensaver() {
                print("🔄 State Machine: 忽略解锁事件，因为刚刚通过屏保恢复")
                return .none
            }
            return settings.screenLockActionIsRestart ? .restartTimer : .resumeTimer
        case (.screenUnlocked, .timerRunning):
            guard settings.screenLockEnabled else { return .none }
            // 如果计时器已经在运行，且刚刚通过屏保恢复，则忽略解锁事件
            if wasRecentlyResumedByScreensaver() {
                print("🔄 State Machine: 忽略解锁事件，因为刚刚通过屏保恢复")
                return .none
            }
            return settings.screenLockActionIsRestart ? .restartTimer : .none
        case (.screenUnlocked, .forcedSleep):
            guard settings.screenLockEnabled else { return .none }
            // 屏幕解锁时如果是强制睡眠状态，检查是否需要退出
            if !isInStayUpTime() {
                print("🔄 State Machine: 屏幕解锁时不再是熬夜时间，退出强制睡眠")
                return .exitForcedSleep
            } else {
                print("🔄 State Machine: 屏幕解锁时仍在熬夜时间，保持强制睡眠")
                return .none
            }
        case (.screenUnlocked, _):
            // 其他状态下的解锁不做处理
            return .none
            
        // 屏保相关事件
        case (.screensaverStarted, .timerRunning):
            guard settings.screensaverEnabled else { return .none }
            return settings.screensaverActionIsRestart ? .none : .pauseTimer
        case (.screensaverStarted, .restTimerRunning):
            guard settings.screensaverEnabled else { return .none }
            return settings.screensaverActionIsRestart ? .none : .pauseTimer
        case (.screensaverStopped, .timerPausedBySystem):
            guard settings.screensaverEnabled else { return .none }
            // 记录屏保恢复时间，用于过滤后续的解锁事件
            lastScreensaverResumeTime = Date()
            return settings.screensaverActionIsRestart ? .restartTimer : .resumeTimer
        case (.screensaverStopped, .restTimerPausedBySystem):
            guard settings.screensaverEnabled else { return .none }
            // 休息期间屏保停止，恢复休息计时
            lastScreensaverResumeTime = Date()
            return .resumeTimer
        case (.screensaverStopped, .timerRunning):
            guard settings.screensaverEnabled else { return .none }
            // 记录屏保恢复时间
            lastScreensaverResumeTime = Date()
            return settings.screensaverActionIsRestart ? .restartTimer : .none
        case (.screensaverStopped, .restTimerRunning):
            guard settings.screensaverEnabled else { return .none }
            // 休息期间屏保停止，不需要额外动作
            lastScreensaverResumeTime = Date()
            return .none
        case (.screensaverStopped, _):
            // 其他状态下的屏保停止不做处理
            return .none
            
        // 休息相关事件
        case (.pomodoroFinished, .timerRunning):
            // 番茄钟完成，进入休息期间
            return .showRestOverlay
        case (.pomodoroFinished, .restPeriod):
            // 已经在休息期间，防止重复触发
            return .none
        case (.restStarted, .restPeriod):
            // 开始休息计时
            return .none
        case (.restFinished, .restTimerRunning):
            // 休息完成，开始下一个番茄钟
            return .startNextPomodoro
        case (.restCancelled, .restPeriod), (.restCancelled, .restTimerRunning), (.restCancelled, .restTimerPausedBySystem):
            // 取消休息，开始下一个番茄钟
            return .startNextPomodoro
            
        // 强制睡眠相关事件
        case (.forcedSleepTriggered, _):
            // 强制睡眠触发，进入强制睡眠状态
            print("🔄 State Machine: 强制睡眠触发，进入强制睡眠状态")
            return .enterForcedSleep
        case (.forcedSleepEnded, .forcedSleep):
            // 强制睡眠结束，退出强制睡眠状态
            print("🔄 State Machine: 强制睡眠结束，退出强制睡眠状态")
            return .exitForcedSleep
        case (.forcedSleepEnded, _):
            // 非强制睡眠状态下的强制睡眠结束事件，忽略
            return .none
            
        // 强制睡眠期间的其他事件处理
        case (.idleTimeExceeded, .forcedSleep):
            // 强制睡眠期间，忽略无操作超时
            print("🔄 State Machine: 强制睡眠期间，忽略无操作超时")
            return .none
        case (.screenLocked, .forcedSleep), (.screensaverStarted, .forcedSleep):
            // 强制睡眠期间，忽略系统事件
            print("🔄 State Machine: 强制睡眠期间，忽略系统事件")
            return .none
            
        default:
            return .none
        }
    }
    
    private func determineNewState(for event: AutoRestartEvent, in state: AutoRestartState) -> AutoRestartState {
        switch event {
        case .timerStarted:
            // 根据当前计时器类型决定状态
            switch currentTimerType {
            case .pomodoro:
                return .timerRunning
            case .shortBreak, .longBreak:
                return .restTimerRunning
            }
        case .timerStopped:
            return .idle
        case .timerPaused:
            // 根据当前状态决定暂停类型
            switch state {
            case .restTimerRunning:
                return .restTimerPausedByUser // 手动暂停休息计时器
            case .timerRunning:
                return .timerPausedByUser // 手动暂停番茄钟计时器
            default:
                return state // 其他状态不变
            }
        case .idleTimeExceeded:
            // 只有在功能启用时才改变状态
            guard settings.idleEnabled else { return state }
            return state == .timerRunning ? .timerPausedByIdle : state
        case .userActivityDetected:
            // 只有在功能启用时才改变状态
            guard settings.idleEnabled else { return state }
            // 只有从无操作暂停状态才能通过用户活动恢复
            return state == .timerPausedByIdle ? .timerRunning : state
        case .screenLocked:
            if settings.screenLockEnabled && !settings.screenLockActionIsRestart {
                switch state {
                case .restTimerRunning:
                    return .restTimerPausedBySystem
                default:
                    return .timerPausedBySystem
                }
            }
            return state
        case .screenUnlocked:
            guard settings.screenLockEnabled else { return state }
            
            // 特殊处理：如果当前是强制睡眠状态，检查是否还在熬夜时间
            if state == .forcedSleep {
                // 检查当前是否还在熬夜时间范围内
                if !isInStayUpTime() {
                    print("🔄 State Machine: 屏幕解锁时检测到不再是熬夜时间，自动退出强制睡眠")
                    // 不再是熬夜时间，应该退出强制睡眠
                    return .idle
                } else {
                    // 仍在熬夜时间，保持强制睡眠状态
                    print("🔄 State Machine: 屏幕解锁时仍在熬夜时间，保持强制睡眠状态")
                    return .forcedSleep
                }
            }
            
            // 从系统暂停状态恢复到相应的运行状态
            switch state {
            case .timerPausedBySystem:
                return .timerRunning
            case .restTimerPausedBySystem:
                return .restTimerRunning
            default:
                return state
            }
        case .screensaverStarted:
            if settings.screensaverEnabled && !settings.screensaverActionIsRestart {
                switch state {
                case .restTimerRunning:
                    return .restTimerPausedBySystem
                default:
                    return .timerPausedBySystem
                }
            }
            return state
        case .screensaverStopped:
            guard settings.screensaverEnabled else { return state }
            // 从系统暂停状态恢复到相应的运行状态
            switch state {
            case .timerPausedBySystem:
                return .timerRunning
            case .restTimerPausedBySystem:
                return .restTimerRunning
            default:
                return state
            }
        case .pomodoroFinished:
            // 番茄钟完成，进入休息期间
            currentTimerType = .pomodoro // 重置为番茄钟类型
            return .restPeriod
        case .restStarted:
            // 开始休息计时，根据休息类型设置计时器类型
            return .restTimerRunning
        case .restFinished:
            // 休息完成，回到空闲状态准备下一个番茄钟
            currentTimerType = .pomodoro
            return .idle
        case .restCancelled:
            // 取消休息，回到空闲状态准备下一个番茄钟
            currentTimerType = .pomodoro
            return .idle
        case .forcedSleepTriggered:
            // 强制睡眠触发，进入强制睡眠状态
            return .forcedSleep
        case .forcedSleepEnded:
            // 强制睡眠结束，回到空闲状态
            return .idle
        }
    }
    
    // MARK: - 熬夜限制功能
    
    /// 开始熬夜监控
    func startStayUpMonitoring() {
        guard settings.stayUpLimitEnabled else { return }
        
        // 停止之前的定时器
        stayUpMonitoringTimer?.invalidate()
        
        // 立即检查一次
        updateStayUpStatus()
        
        // 设置定时器，每分钟检查一次
        stayUpMonitoringTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.updateStayUpStatus()
        }
        
        print("🌙 状态机：开始熬夜监控")
    }
    
    /// 停止熬夜监控
    func stopStayUpMonitoring() {
        stayUpMonitoringTimer?.invalidate()
        stayUpMonitoringTimer = nil
        print("🌙 状态机：停止熬夜监控")
    }
    
    /// 检查当前时间是否处于熬夜限制时间范围内
    /// - Returns: 如果当前时间超过设定的熬夜限制时间则返回true
    private func checkStayUpTime() -> Bool {
        guard settings.stayUpLimitEnabled else { return false }
        
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        
        // 将当前时间转换为分钟数（从00:00开始计算）
        let currentTimeInMinutes = currentHour * 60 + currentMinute
        
        // 将设定的熬夜限制时间转换为分钟数
        let limitTimeInMinutes = settings.stayUpLimitHour * 60 + settings.stayUpLimitMinute
        
        // 处理跨日期的情况
        if settings.stayUpLimitHour >= 21 {
            // 如果限制时间是21:00-23:59，则当前时间超过限制时间就算熬夜
            return currentTimeInMinutes >= limitTimeInMinutes
        } else {
            // 如果限制时间是00:00-01:00（次日），则需要考虑跨日期
            // 当前时间在00:00-01:00之间，或者在21:00-23:59之间都算熬夜
            return currentTimeInMinutes <= limitTimeInMinutes || currentTimeInMinutes >= 21 * 60
        }
    }
    
    /// 更新熬夜状态并触发相应的处理
    private func updateStayUpStatus() {
        let wasStayUpTime = isStayUpTime
        isStayUpTime = checkStayUpTime()
        
        // 检查是否需要显示倒计时警告
        checkForCountdownWarnings()
        
        // 如果从非熬夜时间进入熬夜时间，立即触发熬夜遮罩
        if !wasStayUpTime && isStayUpTime {
            print("🌙 状态机：检测到熬夜时间，触发强制睡眠事件")
            // 这里需要通过回调通知外部触发强制睡眠
            onStayUpTimeChanged?(true)
        }
        // 如果从熬夜时间退出到非熬夜时间，且当前处于强制睡眠状态，则结束强制睡眠
        else if wasStayUpTime && !isStayUpTime && isInForcedSleep() {
            print("🌙 状态机：熬夜时间结束，触发强制睡眠结束事件")
            onStayUpTimeChanged?(false)
        }
    }
    
    /// 检查是否需要显示强制睡眠倒计时警告
    private func checkForCountdownWarnings() {
        guard settings.stayUpLimitEnabled && !isStayUpTime else { return }
        
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: now)
        
        guard let currentHour = components.hour, let currentMinute = components.minute else { return }
        
        // 计算到强制睡眠时间的分钟数
        let limitHour = settings.stayUpLimitHour
        let limitMinute = settings.stayUpLimitMinute
        
        // 处理跨天情况
        var targetMinutes = limitHour * 60 + limitMinute
        let currentMinutes = currentHour * 60 + currentMinute
        
        // 如果限制时间小于当前时间，说明是第二天的时间
        if targetMinutes <= currentMinutes {
            targetMinutes += 24 * 60 // 加上一天的分钟数
        }
        
        let minutesUntilForcedSleep = targetMinutes - currentMinutes
        
        // 检查是否需要显示5分钟警告
        if minutesUntilForcedSleep == 5 {
            print("🌙 状态机：强制睡眠前5分钟警告")
            onCountdownWarning?(5)
        }
        // 检查是否需要显示1分钟警告
        else if minutesUntilForcedSleep == 1 {
            print("🌙 状态机：强制睡眠前1分钟警告")
            onCountdownWarning?(1)
        }
    }
    
    /// 熬夜时间变化回调
    var onStayUpTimeChanged: ((Bool) -> Void)?
    
    /// 倒计时警告回调 (参数为剩余分钟数)
    var onCountdownWarning: ((Int) -> Void)?
    
    /// 获取熬夜限制设置信息（用于统计和显示）
    func getStayUpLimitInfo() -> (enabled: Bool, hour: Int, minute: Int) {
        return (settings.stayUpLimitEnabled, settings.stayUpLimitHour, settings.stayUpLimitMinute)
    }
}
