import Foundation
import Cocoa


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
    private var currentRestDuration: TimeInterval = 0 // 当前休息周期的总时长（包括累积时间）
    
    /// 当前休息周期选中的遮罩层文案模板（每次休息只选择一次，避免多屏遮罩导致轮播多次递增）
    private(set) var currentRestOverlayMessageTemplate: String?
    private var backgroundFiles: [BackgroundFile] = [] // 遮罩层背景文件列表
    private var currentBackgroundIndex: Int = -1 // 当前背景文件索引，从-1开始，第一次调用时变为0
    
    // 随机播放队列相关
    private var shuffleEnabled: Bool = false // 是否启用随机播放
    private var shuffledQueue: [Int] = [] // 随机顺序的索引队列
    private var currentQueueIndex: Int = 0 // 当前在队列中的位置
    
    // 倒计时通知窗口
    private var countdownNotificationWindow: CountdownNotificationWindow?
    
    // 统计管理器
    private let statisticsManager = StatisticsManager.shared
    
    // 自动重新计时相关属性
    private var pomodoroStateMachine: PomodoroStateMachine
    private var idleTimeMinutes: Int = 10
    private var showCancelRestButton: Bool = true // 是否显示取消休息按钮
    private var meetingMode: Bool = false // 专注模式：静默休息，不显示遮罩层
    
    // 事件监听器引用
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    private var idleTimer: Timer?
    private var lastActivityTime: Date = Date()
    
    // 熬夜功能现在由状态机管理
    
    // 计时器状态现在完全由状态机管理
    
    var isRunning: Bool {
        return timer != nil && pomodoroStateMachine.isInRunningState()
    }
    
    /// 判断是否处于暂停状态
    /// 包括：手动暂停、无操作暂停、系统事件暂停
    var isPausedState: Bool {
        return pomodoroStateMachine.isInPausedState()
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
        if pomodoroStateMachine.isInStayUpTime() {
            return false
        }
        return isLongBreak ? showLongBreakCancelButton : showCancelRestButton
    }
    
    // 便利属性：通过状态机检查是否处于休息期间
    var isInRestPeriod: Bool {
        return pomodoroStateMachine.isInRestPeriod()
    }
    
    var isRestTimerRunning: Bool {
        return pomodoroStateMachine.isRestTimerRunning()
    }
    
    // 测试专用：提供对状态机的访问
    internal var stateMachineForTesting: PomodoroStateMachine {
        return pomodoroStateMachine
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
    /// 强制睡眠结束回调：用于通知外部隐藏遮罩层等
    var onForcedSleepEnded: (() -> Void)?
    
    // MARK: - Initialization
    
    init() {
        // 初始化状态机
        self.pomodoroStateMachine = PomodoroStateMachine(settings: PomodoroStateMachine.PomodoroSettings(
            idleEnabled: false,
            idleActionIsRestart: true,
            screenLockEnabled: false,
            screenLockActionIsRestart: true,
            screensaverEnabled: false,
            screensaverActionIsRestart: true,
            stayUpLimitEnabled: false,
            stayUpLimitHour: 23,
            stayUpLimitMinute: 0
        ))
        
        // 从 SettingsStore 加载随机播放设置
        self.shuffleEnabled = SettingsStore.shuffleBackgrounds
        
        setupNotifications()
        startIdleMonitoring()
        
        // 设置熬夜时间变化回调
        pomodoroStateMachine.onStayUpTimeChanged = { [weak self] isEnteringStayUpTime in
            AppLogger.shared.logStateMachine("StayUpTimeChanged -> entering=\(isEnteringStayUpTime)", tag: "SLEEP")
            if isEnteringStayUpTime {
                self?.triggerStayUpOverlay()
            } else {
                self?.processPomodoroEvent(.forcedSleepEnded)
            }
        }
        
        // 设置倒计时警告回调
        pomodoroStateMachine.onCountdownWarning = { [weak self] minutesRemaining in
            self?.showCountdownWarning(minutesRemaining: minutesRemaining)
        }
        
        // 设置系统唤醒回调，用于刷新状态栏
        pomodoroStateMachine.onSystemWakeup = { [weak self] in
            guard let self = self else { return }
            AppLogger.shared.logStateMachine("SystemWakeup -> 强制刷新状态栏", tag: "SLEEP")
            // 强制触发一次计时器更新，刷新状态栏图标
            self.updateTimeDisplay()
        }
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
        if pomodoroStateMachine.isInStayUpTime() {
            triggerStayUpOverlay()
            return
        }
        
        stop() // 确保之前的计时器已停止
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
        
        // 通知状态机计时器已启动
        processPomodoroEvent(.timerStarted)
        
        // 开始熬夜监控（通过状态机）
        pomodoroStateMachine.startStayUpMonitoring()
        
        // 重新启动无操作监控（如果设置启用了无操作检测且不在强制睡眠状态）
        if idleTimeMinutes > 0 && !pomodoroStateMachine.isInForcedSleep() {
            startIdleMonitoring()
            print("▶️ 计时器启动：重新启动无操作监控")
        }
        
        // 立即更新一次显示
        updateTimeDisplay()
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        
        // 隐藏倒计时通知窗口
        hideCountdownNotification()
        
        // 通知状态机计时器已停止
        processPomodoroEvent(.timerStopped)

        // 暂停后立即刷新显示（用于更新状态栏图标为暂停样式）
        updateTimeDisplay()
    }
    
    func pause() {
        guard isRunning else { return }
        timer?.invalidate()
        timer = nil
        print("⏸️ Timer paused")
        
        // 通知状态机计时器已暂停
        processPomodoroEvent(.timerPaused)

        // 暂停后立即刷新显示（用于更新状态栏图标为暂停样式）
        updateTimeDisplay()
    }
    
    func resume() {
        guard pomodoroStateMachine.isInPausedState() && timer == nil else { return }
        
        // 检查剩余时间是否有效
        if remainingTime <= 0 {
            print("⚠️ Resume skipped: remaining time is \(remainingTime), resetting timer instead")
            remainingTime = 0
            updateTimeDisplay()
            return
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
        
        print("▶️ Timer resumed, remaining time: \(Int(remainingTime/60)):\(String(format: "%02d", Int(remainingTime) % 60))")
        
        // 通知状态机计时器已启动
        processPomodoroEvent(.timerStarted)
        
        updateTimeDisplay()
    }
    
    func reset() {
        stop()
        remainingTime = pomodoroTime
        updateTimeDisplay()
    }
    
    func updateSettings(pomodoroMinutes: Int, breakMinutes: Int, idleRestart: Bool, idleTime: Int, idleActionIsRestart: Bool, screenLockRestart: Bool, screenLockActionIsRestart: Bool, screensaverRestart: Bool, screensaverActionIsRestart: Bool, showCancelRestButton: Bool, longBreakCycle: Int, longBreakTimeMinutes: Int, showLongBreakCancelButton: Bool, accumulateRestTime: Bool, backgroundFiles: [BackgroundFile], shuffleBackgrounds: Bool, stayUpLimitEnabled: Bool, stayUpLimitHour: Int, stayUpLimitMinute: Int, meetingMode: Bool) {
        let oldPomodoroTime = pomodoroTime
        
        pomodoroTime = TimeInterval(pomodoroMinutes * 60)
        breakTime = TimeInterval(breakMinutes * 60)
        idleTimeMinutes = idleTime
        self.showCancelRestButton = showCancelRestButton
        self.meetingMode = meetingMode
        
        // 更新计划设置
        self.longBreakTime = TimeInterval(longBreakTimeMinutes * 60)
        self.longBreakCycle = longBreakCycle
        self.showLongBreakCancelButton = showLongBreakCancelButton
        self.accumulateRestTime = accumulateRestTime
        self.backgroundFiles = backgroundFiles
        
        // 更新随机播放设置
        let shuffleChanged = self.shuffleEnabled != shuffleBackgrounds
        self.shuffleEnabled = shuffleBackgrounds
        
        // 如果随机播放设置发生变化，清空队列以便重新生成
        if shuffleChanged {
            shuffledQueue = []
            currentQueueIndex = 0
            if shuffleBackgrounds {
                print("🎲 启用随机播放模式")
            } else {
                print("🔄 切换到顺序播放模式")
            }
        }
        
        // 更新状态机设置（包含熬夜限制设置）
        let newSettings = PomodoroStateMachine.PomodoroSettings(
            idleEnabled: idleRestart,
            idleActionIsRestart: idleActionIsRestart,
            screenLockEnabled: screenLockRestart,
            screenLockActionIsRestart: screenLockActionIsRestart,
            screensaverEnabled: screensaverRestart,
            screensaverActionIsRestart: screensaverActionIsRestart,
            stayUpLimitEnabled: stayUpLimitEnabled,
            stayUpLimitHour: stayUpLimitHour,
            stayUpLimitMinute: stayUpLimitMinute
        )
        pomodoroStateMachine.updateSettings(newSettings)
        
        // 智能更新剩余时间：只有在必要时才更新
        updateRemainingTimeIfNeeded(oldPomodoroTime: oldPomodoroTime, newPomodoroTime: pomodoroTime)
        
        // 重新启动空闲监控（如果设置有变化且不在强制睡眠状态）
        if idleRestart && !pomodoroStateMachine.isInForcedSleep() {
            startIdleMonitoring()
        } else {
            stopIdleMonitoring()
        }
        
        // 重新启动熬夜监控（通过状态机）
        pomodoroStateMachine.startStayUpMonitoring()
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
    
    func getCompletedPomodoros() -> Int {
        return completedPomodoros
    }
    
    func getLongBreakCycle() -> Int {
        return longBreakCycle
    }
    
    func isMeetingMode() -> Bool {
        return meetingMode
    }
    
    // 即时生效：更新专注模式
    public func setMeetingMode(_ isEnabled: Bool) {
        meetingMode = isEnabled
    }
    
    /// 获取当前休息时间信息
    /// - Returns: (isLongBreak: 是否长休息, breakMinutes: 总休息分钟数)
    /// - Note: 返回实际的总休息时间，包括累积的未完成时间
    func getCurrentBreakInfo() -> (isLongBreak: Bool, breakMinutes: Int) {
        // 如果当前正在休息期间，返回当前休息周期的总时长
        if isInRestPeriod && currentRestDuration > 0 {
            return (isLongBreak, Int(currentRestDuration / 60))
        }
        
        // 如果不在休息期间，返回预计的休息时间
        if isLongBreak {
            // 长休息时间（包括累积时间）
            var totalLongBreakTime = longBreakTime
            if accumulateRestTime && accumulatedRestTime > 0 {
                totalLongBreakTime += accumulatedRestTime
            }
            return (true, Int(totalLongBreakTime / 60))
        } else {
            // 短休息时间（也需要包括累积时间）
            var totalShortBreakTime = breakTime
            if accumulateRestTime && accumulatedRestTime > 0 {
                totalShortBreakTime += accumulatedRestTime
            }
            return (false, Int(totalShortBreakTime / 60))
        }
    }
    
    /// 生成随机播放队列（使用 Fisher-Yates 洗牌算法）
    private func generateShuffledQueue() {
        guard !backgroundFiles.isEmpty else { return }
        
        // 创建索引数组 [0, 1, 2, ...]
        shuffledQueue = Array(0..<backgroundFiles.count)
        
        // Fisher-Yates 洗牌算法
        for i in stride(from: shuffledQueue.count - 1, through: 1, by: -1) {
            let j = Int.random(in: 0...i)
            shuffledQueue.swapAt(i, j)
        }
        
        currentQueueIndex = 0
        print("🎲 生成随机播放队列: \(shuffledQueue.map { backgroundFiles[$0].name })")
    }
    
    func getNextBackgroundIndex() -> Int {
        guard !backgroundFiles.isEmpty else { return 0 }
        
        if shuffleEnabled {
            // 随机模式
            if backgroundFiles.count == 1 {
                currentBackgroundIndex = 0
            } else {
                // 如果队列为空或已播放完，重新生成随机队列
                if shuffledQueue.isEmpty || currentQueueIndex >= shuffledQueue.count {
                    generateShuffledQueue()
                }
                
                // 从队列中获取下一个索引
                currentBackgroundIndex = shuffledQueue[currentQueueIndex]
                currentQueueIndex += 1
                
                print("🎲 随机播放 (\(currentQueueIndex)/\(shuffledQueue.count)): \(backgroundFiles[currentBackgroundIndex].name)")
            }
        } else {
            // 顺序模式
            if backgroundFiles.count > 1 {
                currentBackgroundIndex = (currentBackgroundIndex + 1) % backgroundFiles.count
                print("🔄 顺序播放: \(backgroundFiles[currentBackgroundIndex].name)")
            } else {
                currentBackgroundIndex = 0
            }
        }
        
        return currentBackgroundIndex
    }
    
    func triggerFinish() {
        // 立即触发计时器完成逻辑，用于测试功能
        remainingTime = 0
        timerFinished()
    }
    
    // 测试用方法：设置剩余时间
    func setRemainingTime(_ time: TimeInterval) {
        remainingTime = time
        updateTimeDisplay()
    }
    
    // MARK: - 报告功能
    
    // 单例报告窗口引用
    private var reportWindowInstance: ReportWindow?
    
    /// 显示今日时间分布情况
    func showTodayReport() {
        let reportData = statisticsManager.generateTodayReport()
        if reportWindowInstance == nil {
            reportWindowInstance = ReportWindow()
        }
        reportWindowInstance?.showReport(with: reportData)
    }
    
    // MARK: - Private Methods
    
    private func updateTimer() {
        remainingTime -= 1
        
        updateTimeDisplay()
        
        // 处理倒计时通知（仅在番茄钟模式下）
        let currentTimerType = pomodoroStateMachine.getCurrentTimerType()
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
        
        let currentTimerType = pomodoroStateMachine.getCurrentTimerType()
        
        switch currentTimerType {
        case .pomodoro:
            // 番茄钟完成
            completedPomodoros += 1
            print("🍅 完成第 \(completedPomodoros) 个番茄钟")
            
            // 记录统计数据
            statisticsManager.recordPomodoroCompleted(duration: pomodoroTime)
            
            // 通过状态机处理番茄钟完成事件
            processPomodoroEvent(.pomodoroFinished)
            
        case .shortBreak, .longBreak:
            // 休息自然结束，走 finish 分支，记录 break_finished 并切换下一个番茄钟
            print("✅ Rest period ended")
            finishBreak()
            return
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
        // 强制睡眠：不应开启休息计时（避免事件爆增）
        if isInForcedSleepState {
            AppLogger.shared.logStateMachine("startBreak skipped: forced sleep state.", tag: "TIMER_IDEMPOTENT")
            return
        }
        // Idempotency Guard (幂等性保护):
        // 仅当休息计时器已经在运行时才跳过，
        // 允许从 restPeriod（尚未启动计时器）进入真正的休息计时。
        if isRestTimerRunning {
            AppLogger.shared.logStateMachine("startBreak skipped: rest timer already running.", tag: "TIMER_IDEMPOTENT")
            return
        }
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
        pomodoroStateMachine.setTimerType(.shortBreak)

        // 轮播：每次进入休息，只选一次文案模板（多屏遮罩复用同一模板）
        currentRestOverlayMessageTemplate = SettingsStore.nextOverlayRestMessageTemplate()
        
        // 计算短休息时间（包括累积的时间）
        var totalShortBreakTime = breakTime
        if accumulateRestTime && accumulatedRestTime > 0 {
            totalShortBreakTime += accumulatedRestTime
            print("🎯 累加短休息中断时间 \(Int(accumulatedRestTime/60)) 分钟到短休息")
            accumulatedRestTime = 0 // 重置累积时间
        }
        
        remainingTime = totalShortBreakTime
        currentRestDuration = totalShortBreakTime // 保存总休息时长供 getCurrentBreakInfo() 使用
        print("☕ 开始短休息，时长 \(Int(totalShortBreakTime/60)) 分钟")
        
        // 记录统计数据（使用总时长）
        statisticsManager.recordShortBreakStarted(duration: totalShortBreakTime)
        
        // 通过状态机处理休息开始事件
        processPomodoroEvent(.restStarted)
        start()
    }
    
    /// 启动长休息
    private func startLongBreak() {
        isLongBreak = true
        pomodoroStateMachine.setTimerType(.longBreak)

        // 轮播：每次进入休息，只选一次文案模板（多屏遮罩复用同一模板）
        currentRestOverlayMessageTemplate = SettingsStore.nextOverlayRestMessageTemplate()
        
        // 计算长休息时间（包括累积的时间）
        var totalLongBreakTime = longBreakTime
        if accumulateRestTime && accumulatedRestTime > 0 {
            totalLongBreakTime += accumulatedRestTime
            print("🎯 累加短休息中断时间 \(Int(accumulatedRestTime/60)) 分钟到长休息")
            accumulatedRestTime = 0 // 重置累积时间
        }
        
        remainingTime = totalLongBreakTime
        currentRestDuration = totalLongBreakTime // 保存总休息时长供 getCurrentBreakInfo() 使用
        print("🌟 开始长休息（第 \(completedPomodoros/longBreakCycle) 次），时长 \(Int(totalLongBreakTime/60)) 分钟")
        
        // 记录统计数据
        statisticsManager.recordLongBreakStarted(duration: totalLongBreakTime)
        
        // 通过状态机处理休息开始事件
        processPomodoroEvent(.restStarted)
        start()
    }
    
    /// 取消休息
    /// - Parameter source: 取消来源（"user" | "auto_overlay" | 其他），默认 "user"
    func cancelBreak(source: String = "user") {
        // 如果是强制睡眠状态，禁止用户取消
        if pomodoroStateMachine.isInForcedSleep() {
            print("🚫 强制睡眠期间，用户无法取消休息")
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
            actualDuration: actualDuration,
            source: source
        )
        
        stop()
        isLongBreak = false
        currentRestDuration = 0 // 重置休息时长
        currentRestOverlayMessageTemplate = nil
        
        if source == "user" {
            print("🚫 Rest period cancelled by user")
        } else {
            print("🚫 Rest period cancelled by system: \(source)")
        }
        
        // 通过状态机处理休息取消事件
        processPomodoroEvent(.restCancelled)
        
        // 重新开始番茄钟
        remainingTime = pomodoroTime
        start()
    }

    /// 完成休息（与取消休息不同）：记录 break_finished，并进入下一阶段番茄钟
    func finishBreak() {
        // 允许在强制睡眠期间自然完成休息（仅禁止用户取消）
        
        if accumulateRestTime && !isLongBreak {
            // 如果启用了累积功能且当前是短休息，记录剩余时间
            accumulatedRestTime += remainingTime
            print("💾 累积短休息剩余时间 \(Int(remainingTime/60)) 分钟")
        }
        
        // 计算类型与计划/实际时长
        let breakType = isLongBreak ? "long" : "short"
        let plannedDuration = isLongBreak ? longBreakTime : breakTime
        let actualDuration = plannedDuration - remainingTime
        statisticsManager.recordBreakFinished(
            breakType: breakType,
            plannedDuration: plannedDuration,
            actualDuration: max(0, actualDuration)
        )
        
        stop()
        isLongBreak = false
        currentRestDuration = 0 // 重置休息时长
        currentRestOverlayMessageTemplate = nil
        
        // 通知状态机休息完成（与 timerFinished 中 .restFinished 一致）
        processPomodoroEvent(.restFinished)
        
        // 进入下一次番茄钟
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
    private func processPomodoroEvent(_ event: PomodoroEvent) {
        AppLogger.shared.logStateMachine("Event -> \(event)", tag: "STATE")
        let action = pomodoroStateMachine.processEvent(event)
        AppLogger.shared.logStateMachine("Action <- \(action)", tag: "STATE")
        executePomodoroAction(action)
    }
    
    /// 执行状态机决定的动作
    private func executePomodoroAction(_ action: PomodoroAction) {
        switch action {
        case .none:
            break
        case .pauseTimer:
            AppLogger.shared.logStateMachine("Execute: pauseTimer", tag: "ACTION")
            performPause()
        case .resumeTimer:
            AppLogger.shared.logStateMachine("Execute: resumeTimer", tag: "ACTION")
            performResume()
        case .restartTimer:
            AppLogger.shared.logStateMachine("Execute: restartTimer", tag: "ACTION")
            performRestart()
        case .showRestOverlay:
            // 显示休息遮罩，这个动作会触发onTimerFinished回调
            // 不需要额外操作，因为timerFinished已经处理了
            AppLogger.shared.logStateMachine("Execute: showRestOverlay (via onTimerFinished)", tag: "ACTION")
            break
        case .startNextPomodoro:
            // 开始下一个番茄钟
            AppLogger.shared.logStateMachine("Execute: startNextPomodoro", tag: "ACTION")
            performStartNextPomodoro()
        case .enterForcedSleep:
            // 进入强制睡眠状态
            AppLogger.shared.logStateMachine("Execute: enterForcedSleep", tag: "ACTION")
            performEnterForcedSleep()
        case .exitForcedSleep:
            // 退出强制睡眠状态
            AppLogger.shared.logStateMachine("Execute: exitForcedSleep", tag: "ACTION")
            performExitForcedSleep()
        }
    }
    
    /// 执行暂停操作（不触发状态机事件）
    private func performPause() {
        // 如果计时器已经暂停，则不需要再次暂停
        if timer == nil && pomodoroStateMachine.isInPausedState() {
            return
        }
        
        // 停止计时器
        timer?.invalidate()
        timer = nil
        print("⏸️ Timer paused by state machine")
        AppLogger.shared.logStateMachine("Timer -> paused", tag: "TIMER")

        // 暂停后立即刷新显示（用于更新状态栏图标为暂停样式）
        updateTimeDisplay()
    }
    
    /// 执行恢复操作
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
        
        // 暂停状态现在由状态机管理
        
        // 启动计时器 - 与 start() 方法保持一致
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
        
        // 通知状态机计时器已启动，保持状态一致性
        processPomodoroEvent(.timerStarted)
        
        print("▶️ Timer resumed by state machine, remaining time: \(Int(remainingTime/60)):\(String(format: "%02d", Int(remainingTime) % 60))")
        updateTimeDisplay()
        AppLogger.shared.logStateMachine("Timer -> resumed", tag: "TIMER")
    }
    
    /// 执行重新开始操作
    private func performRestart() {
        timer?.invalidate()
        timer = nil
        
        // 根据状态机的计时器类型设置剩余时间
        let currentTimerType = pomodoroStateMachine.getCurrentTimerType()
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
        
        // 通知状态机计时器已启动，保持状态一致性
        processPomodoroEvent(.timerStarted)
        
        print("🔄 Timer restarted by state machine for \(currentTimerType)")
        updateTimeDisplay()
        AppLogger.shared.logStateMachine("Timer -> restarted for \(currentTimerType)", tag: "TIMER")
    }
    
    /// 执行开始下一个番茄钟操作
    private func performStartNextPomodoro() {
        timer?.invalidate()
        timer = nil
        
        // 重置为番茄钟计时
        pomodoroStateMachine.setTimerType(.pomodoro)
        remainingTime = pomodoroTime
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
        
        // 通知状态机计时器已启动，保持状态一致性
        processPomodoroEvent(.timerStarted)
        
        print("🍅 Starting next pomodoro")
        updateTimeDisplay()
        AppLogger.shared.logStateMachine("Timer -> next pomodoro", tag: "TIMER")
    }
    
    /// 执行进入强制睡眠状态操作
    private func performEnterForcedSleep() {
        print("🌙 执行进入强制睡眠状态")
        // 停止无操作监控，避免在强制睡眠期间被无操作检测中断
        stopIdleMonitoring()
        print("🌙 强制睡眠：停止无操作监控，避免被中断")
        AppLogger.shared.logStateMachine("Enter forced sleep", tag: "SLEEP")
    }
    
    /// 执行退出强制睡眠状态操作
    private func performExitForcedSleep() {
        print("🌅 执行退出强制睡眠状态")
        // 重新启动无操作监控（如果设置启用了无操作检测）
        if idleTimeMinutes > 0 {
            startIdleMonitoring()
            print("▶️ 强制睡眠结束：重新启动无操作监控")
        }
        // 熬夜状态现在由状态机管理，无需手动重置
        AppLogger.shared.logStateMachine("Exit forced sleep", tag: "SLEEP")

        // 通知外部（例如 AppDelegate）可以隐藏遮罩层
        DispatchQueue.main.async { [weak self] in
            self?.onForcedSleepEnded?()
        }
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
        lastActivityTime = Date()
    }
    
    private func checkIdleTime() {
        let currentState = pomodoroStateMachine.getCurrentState()
        let idleTime = Date().timeIntervalSince(lastActivityTime)
        let maxIdleTime = TimeInterval(idleTimeMinutes * 60)
        
        // 使用状态机判断是否处于强制睡眠状态
        if pomodoroStateMachine.isInForcedSleep() {
            return
        }
        
        if idleTime > maxIdleTime {
            // 无操作时间超过设定值，只有在计时器运行时才触发
            if currentState == .timerRunning {
                processPomodoroEvent(.idleTimeExceeded)
            }
        } else {
            // 检测到用户活动，只有在因无操作暂停时才触发
            if currentState == .timerPausedByIdle {
                processPomodoroEvent(.userActivityDetected)
            }
        }
    }
    
    @objc private func screenDidLock() {
        processPomodoroEvent(.screenLocked)
    }
    
    @objc private func screenDidUnlock() {        
        // 先处理解锁事件
        processPomodoroEvent(.screenUnlocked)
        
        // 只有在解锁后计时器恢复运行时才更新活动时间，避免干扰无操作检测
        let currentState = pomodoroStateMachine.getCurrentState()
        if currentState == .timerRunning {
            updateLastActivityTime()
        }
    }
    
    @objc private func screensaverDidStart() {
        print("🌌 Screensaver started")
        processPomodoroEvent(.screensaverStarted)
    }
    
    @objc private func screensaverDidStop() {
        print("🌅 Screensaver stopped")
        
        // 先处理屏保停止事件
        processPomodoroEvent(.screensaverStopped)
        
        // 只有在屏保停止后计时器恢复运行时才更新活动时间，避免干扰无操作检测
        let currentState = pomodoroStateMachine.getCurrentState()
        if currentState == .timerRunning {
            updateLastActivityTime()
        }
    }
    
    // MARK: - 熬夜限制功能（现在由状态机管理）
    
    /// 触发熬夜遮罩层（强制休息）
    private func triggerStayUpOverlay() {
        // 获取熬夜限制设置信息
        let stayUpInfo = pomodoroStateMachine.getStayUpLimitInfo()
        AppLogger.shared.logStateMachine("Trigger stay-up overlay; limit: \(String(format: "%02d:%02d", stayUpInfo.hour, stayUpInfo.minute))", tag: "SLEEP")
        
        // 记录熬夜模式触发统计
        let limitTimeString = String(format: "%02d:%02d", stayUpInfo.hour, stayUpInfo.minute)
        statisticsManager.recordStayUpLateTriggered(
            triggerTime: Date(),
            limitTime: limitTimeString
        )
        
        // 停止当前计时器
        stop()
        
        // 通过状态机处理强制睡眠事件
        processPomodoroEvent(.forcedSleepTriggered)
        
        // 触发遮罩层显示回调
        onTimerFinished?()
    }
    
    /// 添加一个便利属性，用于向后兼容
    var isStayUpTime: Bool {
        return pomodoroStateMachine.isInStayUpTime()
    }
    /// 是否处于强制睡眠状态（用于外部判断是否应启动休息计时）
    var isInForcedSleepState: Bool {
        return pomodoroStateMachine.isInForcedSleep()
    }
    
    /// 显示强制睡眠倒计时警告
    private func showCountdownWarning(minutesRemaining: Int) {
        // 创建倒计时通知窗口（如果还没有）
        if countdownNotificationWindow == nil {
            countdownNotificationWindow = CountdownNotificationWindow()
        }
        AppLogger.shared.logStateMachine("Forced sleep countdown: \(minutesRemaining)m", tag: "SLEEP")
        
        // 根据剩余分钟数显示不同的消息
        switch minutesRemaining {
        case 5:
            countdownNotificationWindow?.messageLabel.stringValue = "5分钟后将进入强制睡眠"
            countdownNotificationWindow?.backgroundView.layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.9).cgColor
        case 1:
            countdownNotificationWindow?.messageLabel.stringValue = "1分钟后将进入强制睡眠"
            countdownNotificationWindow?.backgroundView.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.9).cgColor
        default:
            countdownNotificationWindow?.messageLabel.stringValue = "\(minutesRemaining)分钟后将进入强制睡眠"
            countdownNotificationWindow?.backgroundView.layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.9).cgColor
        }
        
        // 显示通知窗口
        countdownNotificationWindow?.showWithAnimation()
        
        // 3秒后自动隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.countdownNotificationWindow?.hideNotification()
        }
        
        print("🚨 显示强制睡眠倒计时警告: \(minutesRemaining)分钟")
    }
    
    func getStatusBarIconType() -> StatusBarIconType {
        return pomodoroStateMachine.deriveStatusBarIconType(meetingMode: meetingMode)
    }
}
