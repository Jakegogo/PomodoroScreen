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
    // 注意：isInRestPeriod 和 TimerType 现在由状态机管理
    
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
    
    // 倒计时通知窗口
    private var countdownNotificationWindow: CountdownNotificationWindow?
    
    // 统计管理器
    private let statisticsManager = StatisticsManager.shared
    
    // 自动重新计时相关属性
    private var autoRestartStateMachine: AutoRestartStateMachine
    private var idleTimeMinutes: Int = 10
    private var showCancelRestButton: Bool = true // 是否显示取消休息按钮
    
    // 事件监听器引用
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    private var idleTimer: Timer?
    private var lastActivityTime: Date = Date()
    
    // 熬夜功能相关属性
    internal var stayUpLimitEnabled: Bool = false // 是否启用熬夜限制
    internal var stayUpLimitHour: Int = 23 // 熬夜限制小时（21-1点范围）
    internal var stayUpLimitMinute: Int = 0 // 熬夜限制分钟（0, 15, 30, 45）
    internal var isStayUpTime: Bool = false // 当前是否处于熬夜时间
    
    // 计时器状态
    private var isPaused: Bool = false
    
    var isRunning: Bool {
        return timer != nil && !isPaused
    }
    
    /// 判断是否处于传统暂停状态
    /// 包括：手动暂停、无操作暂停、系统事件暂停
    var isPausedState: Bool {
        let currentState = autoRestartStateMachine.getCurrentState()
        
        // 如果手动暂停或系统暂停，返回true
        if isPaused || currentState == .timerPausedByIdle || currentState == .timerPausedBySystem {
            return true
        }
        
        return false
    }
    
    /// 判断是否可以继续计时
    /// 状态说明：
    /// - idle + remainingTime == totalTime: 全新状态，显示"开始"，canResume = false
    /// - idle + 0 < remainingTime < totalTime: 停止但可继续，显示"继续"，canResume = true
    /// - paused: 暂停状态，显示"继续"，canResume = true
    /// - running: 运行状态，显示"停止"，canResume = false
    var canResume: Bool {
        // 简化逻辑：基于暂停状态或剩余时间判断
        return isPausedState || (remainingTime > 0 && remainingTime < getTotalTime())
    }
    
    var shouldShowCancelRestButton: Bool {
        // 如果是熬夜时间，不显示取消按钮
        if isStayUpTime {
            return false
        }
        return isLongBreak ? showLongBreakCancelButton : showCancelRestButton
    }
    
    // 便利属性：通过状态机检查是否处于休息期间
    var isInRestPeriod: Bool {
        return autoRestartStateMachine.isInRestPeriod()
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
        
        // 移除事件监听器
        if let globalMonitor = globalEventMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor = localEventMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
    }
    
    // MARK: - Public Methods
    
    func start() {
        // 检查是否处于熬夜时间，如果是则直接触发熬夜遮罩
        if stayUpLimitEnabled && checkStayUpTime() {
            triggerStayUpOverlay()
            return
        }
        
        stop() // 确保之前的计时器已停止
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
        
        // 通知状态机计时器已启动
        processAutoRestartEvent(.timerStarted)
        
        // 开始熬夜监控（如果启用）
        if stayUpLimitEnabled {
            startStayUpMonitoring()
        }
        
        // 重新启动无操作监控（如果设置启用了无操作检测且不在强制睡眠状态）
        if idleTimeMinutes > 0 && !autoRestartStateMachine.isInForcedSleep() {
            startIdleMonitoring()
            print("▶️ 计时器启动：重新启动无操作监控")
        }
        
        // 立即更新一次显示
        updateTimeDisplay()
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        isPaused = false
        
        // 隐藏倒计时通知窗口
        hideCountdownNotification()
        
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
        
        // 检查剩余时间是否有效
        if remainingTime <= 0 {
            print("⚠️ Resume skipped: remaining time is \(remainingTime), resetting timer instead")
            remainingTime = 0
            updateTimeDisplay()
            return
        }
        
        isPaused = false
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
        
        print("▶️ Timer resumed, remaining time: \(Int(remainingTime/60)):\(String(format: "%02d", Int(remainingTime) % 60))")
        
        // 通知状态机计时器已启动
        processAutoRestartEvent(.timerStarted)
        
        updateTimeDisplay()
    }
    
    func reset() {
        stop()
        remainingTime = pomodoroTime
        updateTimeDisplay()
    }
    
    func updateSettings(pomodoroMinutes: Int, breakMinutes: Int, idleRestart: Bool, idleTime: Int, idleActionIsRestart: Bool, screenLockRestart: Bool, screenLockActionIsRestart: Bool, screensaverRestart: Bool, screensaverActionIsRestart: Bool, showCancelRestButton: Bool, longBreakCycle: Int, longBreakTimeMinutes: Int, showLongBreakCancelButton: Bool, accumulateRestTime: Bool, backgroundFiles: [BackgroundFile], stayUpLimitEnabled: Bool, stayUpLimitHour: Int, stayUpLimitMinute: Int) {
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
        
        // 更新熬夜限制设置
        updateStayUpSettings(enabled: stayUpLimitEnabled, hour: stayUpLimitHour, minute: stayUpLimitMinute)
        
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
        
        // 重新启动空闲监控（如果设置有变化且不在强制睡眠状态）
        if idleRestart && !autoRestartStateMachine.isInForcedSleep() {
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
        
        // 如果计时器未运行且不可继续（即完全空闲状态），更新为新的番茄钟时间
        if !isRunning && !canResume {
            remainingTime = newPomodoroTime
            updateTimeDisplay()
            print("⚙️ Settings updated: Timer fully idle, updated to new pomodoro time (\(Int(newPomodoroTime/60)) minutes)")
            return
        }
        
        // 如果计时器正在运行或可继续（有进度），保持当前剩余时间不变
        if isRunning || canResume {
            updateTimeDisplay() // 只更新显示
            print("⚙️ Settings updated: Timer has progress, keeping current remaining time (\(Int(remainingTime/60)):\(Int(remainingTime.truncatingRemainder(dividingBy: 60))) remaining)")
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
    
    func getRemainingTime() -> TimeInterval {
        return remainingTime
    }
    
    func getTotalTime() -> TimeInterval {
        if isInRestPeriod {
            return isLongBreak ? longBreakTime : breakTime
        } else {
            return pomodoroTime
        }
    }
    
    func getBackgroundFiles() -> [BackgroundFile] {
        return backgroundFiles
    }
    
    /// 获取当前休息时间信息
    func getCurrentBreakInfo() -> (isLongBreak: Bool, breakMinutes: Int) {
        if isLongBreak {
            // 长休息时间（包括累积时间）
            var totalLongBreakTime = longBreakTime
            if accumulateRestTime && accumulatedRestTime > 0 {
                totalLongBreakTime += accumulatedRestTime
            }
            return (true, Int(totalLongBreakTime / 60))
        } else {
            // 短休息时间
            return (false, Int(breakTime / 60))
        }
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
        // 立即触发计时器完成逻辑，用于测试功能
        timerFinished()
    }
    
    // 测试用方法：设置剩余时间
    func setRemainingTime(_ time: TimeInterval) {
        remainingTime = time
        updateTimeDisplay()
    }
    
    // MARK: - 报告功能
    
    /// 显示今日工作报告
    func showTodayReport() {
        let reportData = statisticsManager.generateTodayReport()
        let reportWindow = ReportWindow()
        reportWindow.showReport(with: reportData)
    }
    
    // MARK: - Private Methods
    
    private func updateTimer() {
        remainingTime -= 1
        
        updateTimeDisplay()
        
        // 处理倒计时通知（仅在番茄钟模式下）
        let currentTimerType = autoRestartStateMachine.getCurrentTimerType()
        if currentTimerType == .pomodoro {
            handleCountdownNotification()
        }
        
        if remainingTime <= 0 {
            // 确保时间不会变成负数
            remainingTime = 0
            timerFinished()
        }
    }
    
    private func updateTimeDisplay() {
        let timeString = formatTime(remainingTime)
        onTimeUpdate?(timeString)
    }
    
    // 处理倒计时通知
    private func handleCountdownNotification() {
        let seconds = Int(remainingTime)
        
        if seconds == 30 {
            // 提前30秒显示警告
            showCountdownWarning()
        } else if seconds <= 10 && seconds > 0 {
            // 最后10秒显示倒计时
            showCountdownTimer(seconds)
        } else if seconds == 0 {
            // 隐藏通知窗口
            hideCountdownNotification()
        }
    }
    
    // 显示30秒警告
    private func showCountdownWarning() {
        if countdownNotificationWindow == nil {
            countdownNotificationWindow = CountdownNotificationWindow()
        }
        countdownNotificationWindow?.showWarning()
        print("⏰ 显示30秒休息警告")
    }
    
    // 显示倒计时
    private func showCountdownTimer(_ seconds: Int) {
        if countdownNotificationWindow == nil {
            countdownNotificationWindow = CountdownNotificationWindow()
        }
        countdownNotificationWindow?.showCountdown(seconds)
        print("⏰ 显示倒计时: \(seconds)秒")
    }
    
    // 隐藏倒计时通知
    private func hideCountdownNotification() {
        countdownNotificationWindow?.hideNotification()
        print("⏰ 隐藏倒计时通知")
    }
    
    private func timerFinished() {
        stop()
        
        let currentTimerType = autoRestartStateMachine.getCurrentTimerType()
        
        switch currentTimerType {
        case .pomodoro:
            // 番茄钟完成
            completedPomodoros += 1
            print("🍅 完成第 \(completedPomodoros) 个番茄钟")
            
            // 记录统计数据
            statisticsManager.recordPomodoroCompleted(duration: pomodoroTime)
            
            // 通过状态机处理番茄钟完成事件
            processAutoRestartEvent(.pomodoroFinished)
            
        case .shortBreak, .longBreak:
            // 休息结束
            print("✅ Rest period ended")
            
            // 通过状态机处理休息完成事件
            processAutoRestartEvent(.restFinished)
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
    internal func startShortBreak() {
        isLongBreak = false
        autoRestartStateMachine.setTimerType(.shortBreak)
        remainingTime = breakTime
        print("☕ 开始短休息，时长 \(Int(breakTime/60)) 分钟")
        
        // 记录统计数据
        statisticsManager.recordShortBreakStarted(duration: breakTime)
        
        // 通过状态机处理休息开始事件
        processAutoRestartEvent(.restStarted)
        start()
    }
    
    /// 启动长休息
    private func startLongBreak() {
        isLongBreak = true
        autoRestartStateMachine.setTimerType(.longBreak)
        
        // 计算长休息时间（包括累积的时间）
        var totalLongBreakTime = longBreakTime
        if accumulateRestTime && accumulatedRestTime > 0 {
            totalLongBreakTime += accumulatedRestTime
            print("🎯 累加短休息中断时间 \(Int(accumulatedRestTime/60)) 分钟到长休息")
            accumulatedRestTime = 0 // 重置累积时间
        }
        
        remainingTime = totalLongBreakTime
        print("🌟 开始长休息（第 \(completedPomodoros/longBreakCycle) 次），时长 \(Int(totalLongBreakTime/60)) 分钟")
        
        // 记录统计数据
        statisticsManager.recordLongBreakStarted(duration: totalLongBreakTime)
        
        // 通过状态机处理休息开始事件
        processAutoRestartEvent(.restStarted)
        start()
    }
    
    /// 取消休息（用户主动取消）
    func cancelBreak() {
        // 如果是强制睡眠状态，触发强制睡眠结束事件
        if autoRestartStateMachine.isInForcedSleep() {
            print("🌅 用户取消强制睡眠")
            processAutoRestartEvent(.forcedSleepEnded)
            return
        }
        
        if accumulateRestTime && !isLongBreak {
            // 如果启用了累积功能且当前是短休息，记录剩余时间
            accumulatedRestTime += remainingTime
            print("💾 累积短休息剩余时间 \(Int(remainingTime/60)) 分钟")
        }
        
        // 记录取消休息统计
        let breakType = isLongBreak ? "long" : "short"
        let plannedDuration = isLongBreak ? longBreakTime : breakTime
        let actualDuration = plannedDuration - remainingTime
        statisticsManager.recordBreakCancelled(
            breakType: breakType,
            plannedDuration: plannedDuration,
            actualDuration: actualDuration
        )
        
        stop()
        isLongBreak = false
        
        print("🚫 Rest period cancelled by user")
        
        // 通过状态机处理休息取消事件
        processAutoRestartEvent(.restCancelled)
        
        // 重新开始番茄钟
        remainingTime = pomodoroTime
        start()
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        // 防止显示负数时间，最小显示为 00:00
        let safeTime = max(0, time)
        let minutes = Int(safeTime) / 60
        let seconds = Int(safeTime) % 60
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
        case .showRestOverlay:
            // 显示休息遮罩，这个动作会触发onTimerFinished回调
            // 不需要额外操作，因为timerFinished已经处理了
            break
        case .startNextPomodoro:
            // 开始下一个番茄钟
            performStartNextPomodoro()
        case .enterForcedSleep:
            // 进入强制睡眠状态
            performEnterForcedSleep()
        case .exitForcedSleep:
            // 退出强制睡眠状态
            performExitForcedSleep()
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
        
        // 检查剩余时间是否有效，如果时间已经用完或为负数，则不恢复
        if remainingTime <= 0 {
            print("⚠️ Timer resume skipped: remaining time is \(remainingTime), triggering finish instead")
            remainingTime = 0
            timerFinished()
            return
        }
        
        // 确保设置为非暂停状态
        isPaused = false
        
        // 启动计时器 - 与 start() 方法保持一致
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
        
        print("▶️ Timer resumed by state machine, remaining time: \(Int(remainingTime/60)):\(String(format: "%02d", Int(remainingTime) % 60))")
        updateTimeDisplay()
    }
    
    /// 执行重新开始操作（不触发状态机事件）
    private func performRestart() {
        timer?.invalidate()
        timer = nil
        isPaused = false
        
        // 根据状态机的计时器类型设置剩余时间
        let currentTimerType = autoRestartStateMachine.getCurrentTimerType()
        switch currentTimerType {
        case .pomodoro:
            remainingTime = pomodoroTime
        case .shortBreak:
            remainingTime = breakTime
        case .longBreak:
            remainingTime = longBreakTime
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
        
        print("🔄 Timer restarted by state machine for \(currentTimerType)")
        updateTimeDisplay()
    }
    
    /// 执行开始下一个番茄钟操作（不触发状态机事件）
    private func performStartNextPomodoro() {
        timer?.invalidate()
        timer = nil
        isPaused = false
        
        // 重置为番茄钟计时
        autoRestartStateMachine.setTimerType(.pomodoro)
        remainingTime = pomodoroTime
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
        
        print("🍅 Starting next pomodoro")
        updateTimeDisplay()
    }
    
    /// 执行进入强制睡眠状态操作
    private func performEnterForcedSleep() {
        print("🌙 执行进入强制睡眠状态")
        // 停止无操作监控，避免在强制睡眠期间被无操作检测中断
        stopIdleMonitoring()
        print("🌙 强制睡眠：停止无操作监控，避免被中断")
    }
    
    /// 执行退出强制睡眠状态操作
    private func performExitForcedSleep() {
        print("🌅 执行退出强制睡眠状态")
        // 重新启动无操作监控（如果设置启用了无操作检测）
        if idleTimeMinutes > 0 {
            startIdleMonitoring()
            print("▶️ 强制睡眠结束：重新启动无操作监控")
        }
        // 重置熬夜状态
        isStayUpTime = false
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
        
        // 监听系统活动 - 全局事件（其他应用程序的事件）
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .mouseMoved, .leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.updateLastActivityTime()
        }
        
        // 监听本地事件（本应用程序的事件）
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .mouseMoved, .leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.updateLastActivityTime()
            return event // 返回事件以继续正常处理
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
        let currentState = autoRestartStateMachine.getCurrentState()
        lastActivityTime = Date()
        print("👆 Activity: 检测到用户活动，当前状态=\(currentState)")
    }
    
    private func checkIdleTime() {
        let currentState = autoRestartStateMachine.getCurrentState()
        let idleTime = Date().timeIntervalSince(lastActivityTime)
        let maxIdleTime = TimeInterval(idleTimeMinutes * 60)
        
        // 添加调试日志
        print("🔍 IdleCheck: 当前状态=\(currentState), 无操作时间=\(Int(idleTime))s, 阈值=\(Int(maxIdleTime))s")
        
        // 使用状态机判断是否处于强制睡眠状态
        if autoRestartStateMachine.isInForcedSleep() {
            print("🌙 IdleCheck: 强制睡眠期间，跳过无操作检测")
            return
        }
        
        if idleTime > maxIdleTime {
            // 无操作时间超过设定值，只有在计时器运行时才触发
            if currentState == .timerRunning {
                print("⏸️ IdleCheck: 无操作时间超过阈值，触发暂停事件")
                processAutoRestartEvent(.idleTimeExceeded)
            }
        } else {
            // 检测到用户活动，只有在因无操作暂停时才触发
            if currentState == .timerPausedByIdle {
                print("▶️ IdleCheck: 检测到用户活动，触发恢复事件")
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
    
    // MARK: - 熬夜限制功能
    
    /// 检查当前时间是否处于熬夜限制时间范围内
    /// - Returns: 如果当前时间超过设定的熬夜限制时间则返回true
    private func checkStayUpTime() -> Bool {
        guard stayUpLimitEnabled else { return false }
        
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        
        // 将当前时间转换为分钟数（从00:00开始计算）
        let currentTimeInMinutes = currentHour * 60 + currentMinute
        
        // 将设定的熬夜限制时间转换为分钟数
        let limitTimeInMinutes = stayUpLimitHour * 60 + stayUpLimitMinute
        
        // 处理跨日期的情况
        if stayUpLimitHour >= 21 {
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
        
        // 如果从非熬夜时间进入熬夜时间，立即触发熬夜遮罩
        if !wasStayUpTime && isStayUpTime {
            print("🌙 检测到熬夜时间，强制进入休息模式")
            triggerStayUpOverlay()
        }
    }
    
    /// 触发熬夜遮罩层（强制休息）
    private func triggerStayUpOverlay() {
        // 记录熬夜模式触发统计
        let limitTimeString = String(format: "%02d:%02d", stayUpLimitHour, stayUpLimitMinute)
        statisticsManager.recordStayUpLateTriggered(
            triggerTime: Date(),
            limitTime: limitTimeString
        )
        
        // 停止当前计时器
        stop()
        
        // 设置为熬夜休息状态
        isStayUpTime = true
        
        // 通过状态机处理强制睡眠事件
        processAutoRestartEvent(.forcedSleepTriggered)
        
        // 触发遮罩层显示回调
        onTimerFinished?()
    }
    
    /// 开始定期检查熬夜时间（每分钟检查一次）
    private func startStayUpMonitoring() {
        guard stayUpLimitEnabled else { return }
        
        // 立即检查一次
        updateStayUpStatus()
        
        // 设置定时器，每分钟检查一次
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.updateStayUpStatus()
        }
    }
    
    /// 更新熬夜设置
    /// - Parameters:
    ///   - enabled: 是否启用熬夜限制
    ///   - hour: 限制小时（21-1）
    ///   - minute: 限制分钟（0, 15, 30, 45）
    func updateStayUpSettings(enabled: Bool, hour: Int, minute: Int) {
        stayUpLimitEnabled = enabled
        stayUpLimitHour = hour
        stayUpLimitMinute = minute
        
        print("🌙 熬夜设置更新: \(enabled ? "启用" : "禁用"), 时间: \(hour):\(String(format: "%02d", minute))")
        
        // 如果启用了熬夜限制，立即开始监控
        if enabled {
            startStayUpMonitoring()
        }
    }
}
