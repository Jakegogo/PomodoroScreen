import Foundation

// MARK: - State Machine for Auto Restart Logic

/// 自动重新计时的状态
enum AutoRestartState {
    case idle                    // 空闲状态，等待事件
    case timerRunning           // 计时器运行中
    case timerPausedByIdle      // 因无操作而暂停
    case timerPausedBySystem    // 因系统事件（锁屏、屏保）而暂停
    case awaitingRestart        // 等待重新启动
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
}

/// 自动重新计时的动作
enum AutoRestartAction {
    case none               // 无动作
    case pauseTimer         // 暂停计时器
    case resumeTimer        // 恢复计时器
    case restartTimer       // 重新开始计时器
}

/// 自动重新计时状态机
class AutoRestartStateMachine {
    private var currentState: AutoRestartState = .idle
    private var settings: AutoRestartSettings
    private var lastScreensaverResumeTime: Date?
    
    struct AutoRestartSettings {
        let idleEnabled: Bool
        let idleActionIsRestart: Bool
        let screenLockEnabled: Bool
        let screenLockActionIsRestart: Bool
        let screensaverEnabled: Bool
        let screensaverActionIsRestart: Bool
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
            guard settings.idleEnabled else { return .none }
            return .pauseTimer
        case (.userActivityDetected, .timerPausedByIdle):
            guard settings.idleEnabled else { return .none }
            return settings.idleActionIsRestart ? .restartTimer : .resumeTimer
        case (.userActivityDetected, .timerPausedBySystem):
            // 系统事件暂停期间，用户活动不应该触发重新计时
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
        case (.screenUnlocked, _):
            // 其他状态下的解锁不做处理
            return .none
            
        // 屏保相关事件
        case (.screensaverStarted, .timerRunning):
            guard settings.screensaverEnabled else { return .none }
            return settings.screensaverActionIsRestart ? .none : .pauseTimer
        case (.screensaverStopped, .timerPausedBySystem):
            guard settings.screensaverEnabled else { return .none }
            // 记录屏保恢复时间，用于过滤后续的解锁事件
            lastScreensaverResumeTime = Date()
            return settings.screensaverActionIsRestart ? .restartTimer : .resumeTimer
        case (.screensaverStopped, .timerRunning):
            guard settings.screensaverEnabled else { return .none }
            // 记录屏保恢复时间
            lastScreensaverResumeTime = Date()
            return settings.screensaverActionIsRestart ? .restartTimer : .none
        case (.screensaverStopped, _):
            // 其他状态下的屏保停止不做处理
            return .none
            
        default:
            return .none
        }
    }
    
    private func determineNewState(for event: AutoRestartEvent, in state: AutoRestartState) -> AutoRestartState {
        switch event {
        case .timerStarted:
            return .timerRunning
        case .timerStopped:
            return .idle
        case .timerPaused:
            return .timerPausedBySystem // 手动暂停视为系统暂停
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
            return settings.screenLockEnabled && !settings.screenLockActionIsRestart ? .timerPausedBySystem : state
        case .screenUnlocked:
            guard settings.screenLockEnabled else { return state }
            // 从系统暂停状态恢复到运行状态
            return state == .timerPausedBySystem ? .timerRunning : state
        case .screensaverStarted:
            return settings.screensaverEnabled && !settings.screensaverActionIsRestart ? .timerPausedBySystem : state
        case .screensaverStopped:
            guard settings.screensaverEnabled else { return state }
            // 从系统暂停状态恢复到运行状态
            return state == .timerPausedBySystem ? .timerRunning : state
        }
    }
}
