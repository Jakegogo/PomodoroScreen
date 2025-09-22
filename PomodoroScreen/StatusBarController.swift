import Cocoa

class StatusBarController {
    
    // MARK: - Properties
    
    private var statusItem: NSStatusItem
    private var pomodoroTimer: PomodoroTimer
    private var settingsWindow: SettingsWindow?
    private var popupWindow: StatusBarPopupWindow?
    private var isPopupVisible = false
    private var globalEventMonitor: Any?
    private var clockIconGenerator: ClockIconGenerator
    
    // 状态栏显示设置
    private var showStatusBarText: Bool = true
    
    // MARK: - Initialization
    
    init(timer: PomodoroTimer) {
        self.pomodoroTimer = timer
        self.clockIconGenerator = ClockIconGenerator()
        
        // 加载状态栏文字显示设置
        self.showStatusBarText = UserDefaults.standard.bool(forKey: "ShowStatusBarText") != false // 默认为 true
        
        // 创建状态栏项目
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        setupStatusItem()
    }
    
    // MARK: - Public Methods
    
    func updateTime(_ timeString: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 获取倒计时信息
            let remainingTime = self.pomodoroTimer.getRemainingTime()
            let totalTime = self.pomodoroTimer.getTotalTime()
            
            // 计算进度（0.0表示开始，1.0表示结束）
            let progress = totalTime > 0 ? (totalTime - remainingTime) / totalTime : 0.0
            
            // 生成动态时钟图标
            let clockIcon = self.clockIconGenerator.generateClockIcon(
                progress: progress,
                totalTime: totalTime,
                remainingTime: remainingTime
            )
            
            // 更新状态栏图标和文字
            self.statusItem.button?.image = clockIcon
            self.statusItem.button?.title = self.showStatusBarText ? "\(timeString)" : "" // 根据设置显示或隐藏文字
            self.statusItem.button?.imagePosition = .imageLeading // 图标在左，文字在右
            
            // 设置工具提示显示时间信息
            self.statusItem.button?.toolTip = "番茄钟倒计时: \(timeString)"
            
            // 同时更新健康环视图的倒计时显示
            self.popupWindow?.updateCountdown(time: remainingTime, title: "")
        }
    }
    
    // MARK: - Private Methods
    
    private func setupStatusItem() {
        guard let button = statusItem.button else { return }
        
        // 设置初始时钟图标（进度为0）
        let initialIcon = clockIconGenerator.generateClockIcon(
            progress: 0.0,
            totalTime: 25 * 60, // 25分钟
            remainingTime: 25 * 60
        )
        button.image = initialIcon
        button.title = showStatusBarText ? "25:00" : "" // 根据设置显示或隐藏文字
        button.imagePosition = .imageLeading // 图标在左，文字在右
        button.toolTip = "番茄钟倒计时: 25:00"
        
        // 设置等宽字体，避免数字变化时宽度跳动
        button.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        
        // 设置点击事件，不再使用菜单
        button.target = self
        button.action = #selector(togglePopup)
        
        // 创建弹出窗口
        setupPopupWindow()
    }
    
    private func setupPopupWindow() {
        popupWindow = StatusBarPopupWindow()
        
        // 设置菜单按钮点击事件
        popupWindow?.setMenuButtonAction { [weak self] in
            self?.showContextMenu()
        }
        
        // 设置控制按钮点击事件（开始/停止/继续）
        popupWindow?.setControlButtonAction { [weak self] in
            self?.handleControlButtonClicked()
        }
        
        // 设置重置按钮点击事件
        popupWindow?.setResetButtonAction { [weak self] in
            self?.resetTimer()
        }
        
        // 设置健康环点击事件
        popupWindow?.setHealthRingsClickedAction { [weak self] in
            self?.hidePopup()
            self?.showTodayReport()
        }
        
        // 更新健康环数据
        updateHealthRingsData()
        
        // 初始化按钮状态
        updatePopupButtonStates()
    }
    
    @objc private func togglePopup() {
        guard popupWindow != nil else { return }
        
        if isPopupVisible {
            hidePopup()
        } else {
            showPopup()
        }
    }
    
    private func showPopup() {
        guard let popup = popupWindow,
              let button = statusItem.button else { return }
        
        // 更新健康环数据
        updateHealthRingsData()
        
        // 更新按钮状态
        updatePopupButtonStates()
        
        // 更新窗口位置
        popup.updatePosition(relativeTo: button)
        
        // 显示弹出窗口
        popup.showPopup()
        isPopupVisible = true
        
        // 监听点击事件以隐藏弹出窗口 - 暂时禁用自动隐藏
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handleGlobalClick(event)
        }
    }
    
    private func hidePopup() {
        popupWindow?.hidePopup()
        isPopupVisible = false
        
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
    }
    
    private func handleGlobalClick(_ event: NSEvent) {
        guard let popup = popupWindow else { return }
        
        // 获取全局鼠标位置
        let clickLocation = NSEvent.mouseLocation
        let windowFrame = popup.frame
        
        // 如果点击在弹出窗口外部，隐藏窗口
        if !windowFrame.contains(clickLocation) {
            hidePopup()
        }
    }
    
    private func updateHealthRingsData() {
        // 从统计管理器获取今日数据
        let reportData = StatisticsManager.shared.generateTodayReport()
        let daily = reportData.dailyStats
        
        // 计算各项指标（0-100分）
        let restAdequacyScore = daily.restAdequacyScore
        let workIntensityScore = daily.workIntensityScore
        let focusScore = daily.focusScore
        let healthScore = daily.healthScore
        
        // 转换为0-1范围，供HealthRingsView使用
        // 如果没有数据，使用一些示例数据来展示圆环效果
        let restAdequacy = restAdequacyScore > 0 ? restAdequacyScore / 100.0 : 0.3
        let workIntensity = workIntensityScore > 0 ? workIntensityScore / 100.0 : 0.6
        let focus = focusScore > 0 ? focusScore / 100.0 : 0.8
        let health = healthScore > 20 ? healthScore / 100.0 : 0.4  // healthScore默认最低20
        
        // 调试输出，查看实际数值
        print("🔍 Health Ring Scores: rest=\(restAdequacyScore), work=\(workIntensityScore), focus=\(focusScore), health=\(healthScore)")
        print("🔍 Ring Progress Values (0-1): rest=\(restAdequacy), work=\(workIntensity), focus=\(focus), health=\(health)")
        
        popupWindow?.updateHealthData(
            restAdequacy: restAdequacy,
            workIntensity: workIntensity,
            focus: focus,
            health: health
        )
    }
    
    private func showContextMenu() {
        // 创建上下文菜单
        let menu = NSMenu()
        
        // 开始/暂停/继续按钮逻辑
        // 根据优化后的状态表确定菜单显示：
        // - Running: 显示"停止"
        // - Idle(停止但可继续): 显示"继续" 
        // - Pause: 显示"继续"
        // - Idle(全新): 显示"开始"
        var title: String
        var action: Selector
        
        if pomodoroTimer.isRunning {
            // 计时器正在运行 - 显示"停止"
            title = "停止"
            action = #selector(stopTimer)
        } else if pomodoroTimer.canResume {
            // 计时器可以继续（暂停或停止但有进度） - 显示"继续"
            title = "继续"
            action = #selector(startTimer)
        } else {
            // 计时器完全空闲（全新状态） - 显示"开始"
            title = "开始"
            action = #selector(startTimer)
        }
        
        let startItem = NSMenuItem(title: title, action: action, keyEquivalent: "")
        startItem.target = self
        menu.addItem(startItem)
        
        // 重置按钮
        let resetItem = NSMenuItem(title: "重置", action: #selector(resetTimer), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 立即完成按钮（用于测试遮罩层）
        let testFinishItem = NSMenuItem(title: "立即完成", action: #selector(testFinishTimer), keyEquivalent: "")
        testFinishItem.target = self
        menu.addItem(testFinishItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 今日报告按钮
        let reportItem = NSMenuItem(title: "今日报告", action: #selector(showTodayReport), keyEquivalent: "r")
        reportItem.target = self
        menu.addItem(reportItem)
        
        // 设置按钮
        let settingsItem = NSMenuItem(title: "设置", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        // 退出按钮
        let quitItem = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        // 在鼠标位置显示菜单
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        
        // 菜单显示后隐藏弹出窗口
        hidePopup()
    }
    
    @objc private func startTimer() {
        pomodoroTimer.start()
        // 清除图标缓存以立即更新状态
        clockIconGenerator.clearCache()
        // 更新健康环数据
        updateHealthRingsData()
        // 更新popup按钮状态
        updatePopupButtonStates()
    }
    
    @objc private func stopTimer() {
        pomodoroTimer.stop()
        // 清除图标缓存以立即更新状态
        clockIconGenerator.clearCache()
        // 更新健康环数据
        updateHealthRingsData()
        // 更新popup按钮状态
        updatePopupButtonStates()
    }
    
    @objc private func resetTimer() {
        pomodoroTimer.reset()
        // 清除图标缓存以立即更新状态
        clockIconGenerator.clearCache()
        // 更新健康环数据
        updateHealthRingsData()
        // 更新popup按钮状态
        updatePopupButtonStates()
    }
    
    
    private func handleControlButtonClicked() {
        if pomodoroTimer.isRunning {
            // 计时器正在运行 - 停止
            stopTimer()
        } else if pomodoroTimer.canResume {
            // 计时器可以继续 - 开始/继续
            startTimer()
        } else {
            // 计时器完全空闲 - 开始
            startTimer()
        }
        // 更新popup按钮状态
        updatePopupButtonStates()
    }
    
    private func updatePopupButtonStates() {
        var title: String
        
        if pomodoroTimer.isRunning {
            title = "停止"
        } else if pomodoroTimer.canResume {
            title = "继续"
        } else {
            title = "开始"
        }
        
        popupWindow?.updateControlButtonTitle(title)
    }
    
    @objc private func testFinishTimer() {
        // 立即触发计时器完成，用于测试遮罩层
        pomodoroTimer.triggerFinish()
    }
    
    @objc private func showSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 400),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            
            settingsWindow?.onSettingsChanged = { [weak self] autoStart, pomodoroTime, breakTime, idleRestart, idleTime, idleActionIsRestart, screenLockRestart, screenLockActionIsRestart, screensaverRestart, screensaverActionIsRestart, showCancelRestButton, longBreakCycle, longBreakTimeMinutes, showLongBreakCancelButton, accumulateRestTime, backgroundFiles, stayUpLimitEnabled, stayUpLimitHour, stayUpLimitMinute, showStatusBarText in
                self?.applySettings(autoStart: autoStart, pomodoroTime: pomodoroTime, breakTime: breakTime, idleRestart: idleRestart, idleTime: idleTime, idleActionIsRestart: idleActionIsRestart, screenLockRestart: screenLockRestart, screenLockActionIsRestart: screenLockActionIsRestart, screensaverRestart: screensaverRestart, screensaverActionIsRestart: screensaverActionIsRestart, showCancelRestButton: showCancelRestButton, longBreakCycle: longBreakCycle, longBreakTimeMinutes: longBreakTimeMinutes, showLongBreakCancelButton: showLongBreakCancelButton, accumulateRestTime: accumulateRestTime, backgroundFiles: backgroundFiles, stayUpLimitEnabled: stayUpLimitEnabled, stayUpLimitHour: stayUpLimitHour, stayUpLimitMinute: stayUpLimitMinute, showStatusBarText: showStatusBarText)
            }
        }
        
        settingsWindow?.showSettings()
    }
    
    @objc private func showTodayReport() {
        pomodoroTimer.showTodayReport()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func applySettings(autoStart: Bool, pomodoroTime: Int, breakTime: Int, idleRestart: Bool, idleTime: Int, idleActionIsRestart: Bool, screenLockRestart: Bool, screenLockActionIsRestart: Bool, screensaverRestart: Bool, screensaverActionIsRestart: Bool, showCancelRestButton: Bool, longBreakCycle: Int, longBreakTimeMinutes: Int, showLongBreakCancelButton: Bool, accumulateRestTime: Bool, backgroundFiles: [BackgroundFile], stayUpLimitEnabled: Bool, stayUpLimitHour: Int, stayUpLimitMinute: Int, showStatusBarText: Bool) {
        // 记录当前计时器状态
        let wasRunning = pomodoroTimer.isRunning
        let wasPaused = pomodoroTimer.isPausedState
        
        // 更新计时器设置
        pomodoroTimer.updateSettings(pomodoroMinutes: pomodoroTime, breakMinutes: breakTime, idleRestart: idleRestart, idleTime: idleTime, idleActionIsRestart: idleActionIsRestart, screenLockRestart: screenLockRestart, screenLockActionIsRestart: screenLockActionIsRestart, screensaverRestart: screensaverRestart, screensaverActionIsRestart: screensaverActionIsRestart, showCancelRestButton: showCancelRestButton, longBreakCycle: longBreakCycle, longBreakTimeMinutes: longBreakTimeMinutes, showLongBreakCancelButton: showLongBreakCancelButton, accumulateRestTime: accumulateRestTime, backgroundFiles: backgroundFiles, stayUpLimitEnabled: stayUpLimitEnabled, stayUpLimitHour: stayUpLimitHour, stayUpLimitMinute: stayUpLimitMinute)
        
        // 更新状态栏文字显示设置
        self.showStatusBarText = showStatusBarText
        
        // 更新状态栏显示
        updateTime(pomodoroTimer.getRemainingTimeString())
        
        // 只有在计时器完全空闲（未运行且未暂停）且启用自动启动时，才启动计时器
        if autoStart && !wasRunning && !wasPaused {
            print("⚙️ Settings applied: Auto-start enabled and timer was idle, starting timer")
            startTimer()
        } else if wasRunning || wasPaused {
            print("⚙️ Settings applied: Timer was active, preserving current state")
        } else {
            print("⚙️ Settings applied: Auto-start disabled or timer was already configured")
        }
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
