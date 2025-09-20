import Foundation
import Cocoa

// 背景文件数据结构
struct BackgroundFile: Codable {
    let path: String // 文件路径
    let type: BackgroundType // 文件类型
    let name: String // 显示名称
    let playbackRate: Double // 视频播放速率（0.1-8.0，默认1.0）
    
    enum BackgroundType: String, Codable, CaseIterable {
        case image = "image"
        case video = "video"
        
        var displayName: String {
            switch self {
            case .image: return "图片"
            case .video: return "视频"
            }
        }
    }
}

class PomodoroTimer: ObservableObject {
    
    // MARK: - Properties
    
    private var timer: Timer?
    private var remainingTime: TimeInterval = 25 * 60 // 默认25分钟
    private var pomodoroTime: TimeInterval = 25 * 60 // 可配置的番茄钟时间
    private var breakTime: TimeInterval = 3 * 60 // 可配置的休息时间
    
    // 计划相关属性
    private var longBreakTime: TimeInterval = 5 * 60 // 长休息时间
    private var longBreakCycle: Int = 2 // 间隔N次后进行长休息
    private var completedPomodoros: Int = 0 // 已完成的番茄钟次数
    private var showLongBreakCancelButton: Bool = true // 长休息是否显示取消按钮
    private var accumulateRestTime: Bool = false // 是否累加短休息中断时间
    private var accumulatedRestTime: TimeInterval = 0 // 累积的休息时间
    internal var isLongBreak: Bool = false // 当前是否为长休息
    private var backgroundFiles: [BackgroundFile] = [] // 遮罩层背景文件列表
    private var currentBackgroundIndex: Int = -1 // 当前背景文件索引，从-1开始，第一次调用时变为0
    
    // 自动重新计时相关属性
    private var autoRestartStateMachine: AutoRestartStateMachine
    private var idleTimeMinutes: Int = 10
    private var showCancelRestButton: Bool = true // 是否显示取消休息按钮
    private var idleTimer: Timer?
    private var lastActivityTime: Date = Date()
    
    // 计时器状态
    private var isPaused: Bool = false
    
    var isRunning: Bool {
        return timer != nil && !isPaused
    }
    
    var isPausedState: Bool {
        let currentState = autoRestartStateMachine.getCurrentState()
        return isPaused || currentState == .timerPausedByIdle || currentState == .timerPausedBySystem
    }
    
    var shouldShowCancelRestButton: Bool {
        return isLongBreak ? showLongBreakCancelButton : showCancelRestButton
    }
    
    // 测试专用：提供对状态机的访问
    internal var stateMachineForTesting: AutoRestartStateMachine {
        return autoRestartStateMachine
    }
    
    // 测试专用：模拟屏保事件
    internal func simulateScreensaverStart() {
        print("🧪 模拟屏保启动")
        screensaverDidStart()
    }
    
    internal func simulateScreensaverStop() {
        print("🧪 模拟屏保停止")
        screensaverDidStop()
    }
    
    // 测试专用：模拟锁屏事件
    internal func simulateScreenLock() {
        print("🧪 模拟锁屏")
        screenDidLock()
    }
    
    internal func simulateScreenUnlock() {
        print("🧪 模拟解锁")
        screenDidUnlock()
    }
    
    // 测试专用：模拟用户活动
    internal func simulateUserActivity() {
        print("🧪 模拟用户活动")
        updateLastActivityTime()
    }
    
    // 回调闭包
    var onTimerFinished: (() -> Void)?
    var onTimeUpdate: ((String) -> Void)?
    
    // MARK: - Initialization
    
    init() {
        // 初始化状态机
        self.autoRestartStateMachine = AutoRestartStateMachine(settings: AutoRestartStateMachine.AutoRestartSettings(
            idleEnabled: false,
            idleActionIsRestart: true,
            screenLockEnabled: false,
            screenLockActionIsRestart: true,
            screensaverEnabled: false,
            screensaverActionIsRestart: true
        ))
        
        setupNotifications()
        startIdleMonitoring()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        DistributedNotificationCenter.default.removeObserver(self)
        idleTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    func start() {
        stop() // 确保之前的计时器已停止
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
        
        // 通知状态机计时器已启动
        processAutoRestartEvent(.timerStarted)
        
        // 立即更新一次显示
        updateTimeDisplay()
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        isPaused = false
        
        // 通知状态机计时器已停止
        processAutoRestartEvent(.timerStopped)
    }
    
    func pause() {
        guard isRunning else { return }
        timer?.invalidate()
        timer = nil
        isPaused = true
        print("⏸️ Timer paused")
        
        // 通知状态机计时器已暂停
        processAutoRestartEvent(.timerPaused)
    }
    
    func resume() {
        guard isPaused && timer == nil else { return }
        isPaused = false
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
        
        print("▶️ Timer resumed")
        
        // 通知状态机计时器已启动
        processAutoRestartEvent(.timerStarted)
        
        updateTimeDisplay()
    }
    
    func reset() {
        stop()
        remainingTime = pomodoroTime
        updateTimeDisplay()
    }
    
    func updateSettings(pomodoroMinutes: Int, breakMinutes: Int, idleRestart: Bool, idleTime: Int, idleActionIsRestart: Bool, screenLockRestart: Bool, screenLockActionIsRestart: Bool, screensaverRestart: Bool, screensaverActionIsRestart: Bool, showCancelRestButton: Bool, longBreakCycle: Int, longBreakTimeMinutes: Int, showLongBreakCancelButton: Bool, accumulateRestTime: Bool, backgroundFiles: [BackgroundFile]) {
        let oldPomodoroTime = pomodoroTime
        
        pomodoroTime = TimeInterval(pomodoroMinutes * 60)
        breakTime = TimeInterval(breakMinutes * 60)
        idleTimeMinutes = idleTime
        self.showCancelRestButton = showCancelRestButton
        
        // 更新计划设置
        self.longBreakTime = TimeInterval(longBreakTimeMinutes * 60)
        self.longBreakCycle = longBreakCycle
        self.showLongBreakCancelButton = showLongBreakCancelButton
        self.accumulateRestTime = accumulateRestTime
        self.backgroundFiles = backgroundFiles
        
        // 更新状态机设置
        let newSettings = AutoRestartStateMachine.AutoRestartSettings(
            idleEnabled: idleRestart,
            idleActionIsRestart: idleActionIsRestart,
            screenLockEnabled: screenLockRestart,
            screenLockActionIsRestart: screenLockActionIsRestart,
            screensaverEnabled: screensaverRestart,
            screensaverActionIsRestart: screensaverActionIsRestart
        )
        autoRestartStateMachine.updateSettings(newSettings)
        
        // 智能更新剩余时间：只有在必要时才更新
        updateRemainingTimeIfNeeded(oldPomodoroTime: oldPomodoroTime, newPomodoroTime: pomodoroTime)
        
        // 重新启动空闲监控（如果设置有变化）
        if idleRestart {
            startIdleMonitoring()
        } else {
            stopIdleMonitoring()
        }
    }
    
    /// 智能更新剩余时间，避免不必要的重启
    private func updateRemainingTimeIfNeeded(oldPomodoroTime: TimeInterval, newPomodoroTime: TimeInterval) {
        // 如果番茄钟时间没有变化，不需要更新
        if oldPomodoroTime == newPomodoroTime {
            updateTimeDisplay() // 只更新显示
            return
        }
        
        // 如果计时器未运行且未暂停（即空闲状态），更新为新的番茄钟时间
        if !isRunning && !isPausedState {
            remainingTime = newPomodoroTime
            updateTimeDisplay()
            print("⚙️ Settings updated: Timer idle, updated to new pomodoro time (\(Int(newPomodoroTime/60)) minutes)")
            return
        }
        
        // 如果计时器正在运行或已暂停，保持当前剩余时间不变
        if isRunning || isPausedState {
            updateTimeDisplay() // 只更新显示
            print("⚙️ Settings updated: Timer active, keeping current remaining time (\(Int(remainingTime/60)):\(Int(remainingTime.truncatingRemainder(dividingBy: 60))) remaining)")
            return
        }
        
        // 其他情况，更新为新的番茄钟时间
        remainingTime = newPomodoroTime
        updateTimeDisplay()
        print("⚙️ Settings updated: Updated to new pomodoro time (\(Int(newPomodoroTime/60)) minutes)")
    }
    
    func getRemainingTimeString() -> String {
        return formatTime(remainingTime)
    }
    
    func getBackgroundFiles() -> [BackgroundFile] {
        return backgroundFiles
    }
    
    func getNextBackgroundIndex() -> Int {
        guard !backgroundFiles.isEmpty else { return 0 }
        
        // 每次调用时切换到下一个背景
        if backgroundFiles.count > 1 {
            currentBackgroundIndex = (currentBackgroundIndex + 1) % backgroundFiles.count
            print("🔄 切换到下一个背景: \(backgroundFiles[currentBackgroundIndex].name)")
        } else {
            // 如果只有一个文件，确保索引为0
            currentBackgroundIndex = 0
        }
        
        return currentBackgroundIndex
    }
    
    func triggerFinish() {
        // 立即触发遮罩层显示，用于测试功能（不停止计时器）
        onTimerFinished?()
    }
    
    // MARK: - Private Methods
    
    private func updateTimer() {
        remainingTime -= 1
        
        updateTimeDisplay()
        
        if remainingTime <= 0 {
            timerFinished()
        }
    }
    
    private func updateTimeDisplay() {
        let timeString = formatTime(remainingTime)
        onTimeUpdate?(timeString)
    }
    
    private func timerFinished() {
        stop()
        
        // 如果当前是番茄钟计时（不是休息），增加完成计数
        if !isInBreak {
            completedPomodoros += 1
            print("🍅 完成第 \(completedPomodoros) 个番茄钟")
        }
        
        onTimerFinished?()
    }
    
    // 判断当前是否处于休息状态
    private var isInBreak: Bool {
        return remainingTime != pomodoroTime
    }
    
    // MARK: - 休息相关方法
    
    /// 启动休息（自动判断短休息还是长休息）
    func startBreak() {
        stop() // 停止当前计时器
        
        // 判断是否应该进行长休息
        let shouldTakeLongBreak = (completedPomodoros % longBreakCycle == 0) && completedPomodoros > 0
        
        if shouldTakeLongBreak {
            startLongBreak()
        } else {
            startShortBreak()
        }
    }
    
    /// 启动短休息
    private func startShortBreak() {
        isLongBreak = false
        remainingTime = breakTime
        print("☕ 开始短休息，时长 \(Int(breakTime/60)) 分钟")
        start()
    }
    
    /// 启动长休息
    private func startLongBreak() {
        isLongBreak = true
        
        // 计算长休息时间（包括累积的时间）
        var totalLongBreakTime = longBreakTime
        if accumulateRestTime && accumulatedRestTime > 0 {
            totalLongBreakTime += accumulatedRestTime
            print("🎯 累加短休息中断时间 \(Int(accumulatedRestTime/60)) 分钟到长休息")
            accumulatedRestTime = 0 // 重置累积时间
        }
        
        remainingTime = totalLongBreakTime
        print("🌟 开始长休息（第 \(completedPomodoros/longBreakCycle) 次），时长 \(Int(totalLongBreakTime/60)) 分钟")
        start()
    }
    
    /// 取消休息（用户主动取消）
    func cancelBreak() {
        if accumulateRestTime && !isLongBreak {
            // 如果启用了累积功能且当前是短休息，记录剩余时间
            accumulatedRestTime += remainingTime
            print("💾 累积短休息剩余时间 \(Int(remainingTime/60)) 分钟")
        }
        
        stop()
        isLongBreak = false
        
        // 重新开始番茄钟
        remainingTime = pomodoroTime
        start()
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - 状态机事件处理
    
    /// 处理自动重新计时事件
    private func processAutoRestartEvent(_ event: AutoRestartEvent) {
        let action = autoRestartStateMachine.processEvent(event)
        executeAutoRestartAction(action)
    }
    
    /// 执行状态机决定的动作
    private func executeAutoRestartAction(_ action: AutoRestartAction) {
        switch action {
        case .none:
            break
        case .pauseTimer:
            performPause()
        case .resumeTimer:
            performResume()
        case .restartTimer:
            performRestart()
        }
    }
    
    /// 执行暂停操作（不触发状态机事件）
    private func performPause() {
        // 如果计时器已经暂停，则不需要再次暂停
        if timer == nil && isPaused {
            return
        }
        
        // 停止计时器并设置暂停状态
        timer?.invalidate()
        timer = nil
        isPaused = true
        print("⏸️ Timer paused by state machine")
    }
    
    /// 执行恢复操作（不触发状态机事件）
    private func performResume() {
        // 更健壮的恢复逻辑：如果计时器已经在运行，则不需要恢复
        if timer != nil {
            return
        }
        
        // 确保设置为非暂停状态
        isPaused = false
        
        // 启动计时器 - 与 start() 方法保持一致
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
        
        print("▶️ Timer resumed by state machine")
        updateTimeDisplay()
    }
    
    /// 执行重新开始操作（不触发状态机事件）
    private func performRestart() {
        timer?.invalidate()
        timer = nil
        isPaused = false
        remainingTime = pomodoroTime
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
        
        print("🔄 Timer restarted by state machine")
        updateTimeDisplay()
    }
    
    // MARK: - 自动重新计时功能
    
    private func setupNotifications() {
        // 监听屏幕锁定/解锁通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenDidLock),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenDidUnlock),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
        
        // 监听会话锁定/解锁通知（更准确的锁屏检测）
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(screenDidLock),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil
        )
        
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(screenDidUnlock),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
        
        // 监听屏保启动/停止通知
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(screensaverDidStart),
            name: NSNotification.Name("com.apple.screensaver.didstart"),
            object: nil
        )
        
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(screensaverDidStop),
            name: NSNotification.Name("com.apple.screensaver.didstop"),
            object: nil
        )
        
        // 监听系统活动
        NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .mouseMoved, .leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.updateLastActivityTime()
        }
    }
    
    private func startIdleMonitoring() {
        stopIdleMonitoring()
        lastActivityTime = Date()
        
        idleTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.checkIdleTime()
        }
    }
    
    private func stopIdleMonitoring() {
        idleTimer?.invalidate()
        idleTimer = nil
    }
    
    private func updateLastActivityTime() {
        lastActivityTime = Date()
    }
    
    private func checkIdleTime() {
        let currentState = autoRestartStateMachine.getCurrentState()
        let idleTime = Date().timeIntervalSince(lastActivityTime)
        let maxIdleTime = TimeInterval(idleTimeMinutes * 60)
        
        if idleTime > maxIdleTime {
            // 无操作时间超过设定值，只有在计时器运行时才触发
            if currentState == .timerRunning {
                processAutoRestartEvent(.idleTimeExceeded)
            }
        } else {
            // 检测到用户活动，只有在因无操作暂停时才触发
            if currentState == .timerPausedByIdle {
                processAutoRestartEvent(.userActivityDetected)
            }
        }
    }
    
    @objc private func screenDidLock() {
        print("📱 Screen lock detected")
        processAutoRestartEvent(.screenLocked)
    }
    
    @objc private func screenDidUnlock() {
        print("🔓 Screen unlock detected")
        
        // 先处理解锁事件
        processAutoRestartEvent(.screenUnlocked)
        
        // 只有在解锁后计时器恢复运行时才更新活动时间，避免干扰无操作检测
        let currentState = autoRestartStateMachine.getCurrentState()
        if currentState == .timerRunning {
            updateLastActivityTime()
        }
    }
    
    @objc private func screensaverDidStart() {
        print("🌌 Screensaver started")
        processAutoRestartEvent(.screensaverStarted)
    }
    
    @objc private func screensaverDidStop() {
        print("🌅 Screensaver stopped")
        
        // 先处理屏保停止事件
        processAutoRestartEvent(.screensaverStopped)
        
        // 只有在屏保停止后计时器恢复运行时才更新活动时间，避免干扰无操作检测
        let currentState = autoRestartStateMachine.getCurrentState()
        if currentState == .timerRunning {
            updateLastActivityTime()
        }
    }
}
