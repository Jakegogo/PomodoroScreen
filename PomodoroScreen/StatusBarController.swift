import Cocoa

class StatusBarController {
    
    // MARK: - Properties
    
    private var statusItem: NSStatusItem
    private var pomodoroTimer: PomodoroTimer
    private var settingsWindow: SettingsWindow?
    private var popupWindow: StatusBarPopupWindow?
    private var isPopupVisible = false
    private var globalEventMonitor: Any?
    
    // MARK: - Initialization
    
    init(timer: PomodoroTimer) {
        self.pomodoroTimer = timer
        
        // 创建状态栏项目
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        setupStatusItem()
    }
    
    // MARK: - Public Methods
    
    func updateTime(_ timeString: String) {
        DispatchQueue.main.async { [weak self] in
            self?.statusItem.button?.title = "🍅 \(timeString)"
        }
    }
    
    // MARK: - Private Methods
    
    private func setupStatusItem() {
        guard let button = statusItem.button else { return }
        
        // 设置初始显示
        button.title = "🍅 25:00"
        
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
        
        // 更新健康环数据
        updateHealthRingsData()
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
        
        // 更新窗口位置
        popup.updatePosition(relativeTo: button)
        
        // 显示弹出窗口
        popup.showPopup()
        isPopupVisible = true
        
        // 监听点击事件以隐藏弹出窗口 - 暂时禁用自动隐藏
        // globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
        //     self?.handleGlobalClick(event)
        // }
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
        
        // 开始/暂停按钮
        let startItem = NSMenuItem(title: pomodoroTimer.isRunning ? "停止" : "开始", 
                                 action: pomodoroTimer.isRunning ? #selector(stopTimer) : #selector(startTimer), 
                                 keyEquivalent: "")
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
        // 更新健康环数据
        updateHealthRingsData()
    }
    
    @objc private func stopTimer() {
        pomodoroTimer.stop()
        // 更新健康环数据
        updateHealthRingsData()
    }
    
    @objc private func resetTimer() {
        pomodoroTimer.reset()
        // 更新健康环数据
        updateHealthRingsData()
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
            
            settingsWindow?.onSettingsChanged = { [weak self] autoStart, pomodoroTime, breakTime, idleRestart, idleTime, idleActionIsRestart, screenLockRestart, screenLockActionIsRestart, screensaverRestart, screensaverActionIsRestart, showCancelRestButton, longBreakCycle, longBreakTimeMinutes, showLongBreakCancelButton, accumulateRestTime, backgroundFiles, stayUpLimitEnabled, stayUpLimitHour, stayUpLimitMinute in
                self?.applySettings(autoStart: autoStart, pomodoroTime: pomodoroTime, breakTime: breakTime, idleRestart: idleRestart, idleTime: idleTime, idleActionIsRestart: idleActionIsRestart, screenLockRestart: screenLockRestart, screenLockActionIsRestart: screenLockActionIsRestart, screensaverRestart: screensaverRestart, screensaverActionIsRestart: screensaverActionIsRestart, showCancelRestButton: showCancelRestButton, longBreakCycle: longBreakCycle, longBreakTimeMinutes: longBreakTimeMinutes, showLongBreakCancelButton: showLongBreakCancelButton, accumulateRestTime: accumulateRestTime, backgroundFiles: backgroundFiles, stayUpLimitEnabled: stayUpLimitEnabled, stayUpLimitHour: stayUpLimitHour, stayUpLimitMinute: stayUpLimitMinute)
            }
        }
        
        settingsWindow?.showSettings()
    }
    
    @objc private func showTodayReport() {
        pomodoroTimer.showTodayReport()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func applySettings(autoStart: Bool, pomodoroTime: Int, breakTime: Int, idleRestart: Bool, idleTime: Int, idleActionIsRestart: Bool, screenLockRestart: Bool, screenLockActionIsRestart: Bool, screensaverRestart: Bool, screensaverActionIsRestart: Bool, showCancelRestButton: Bool, longBreakCycle: Int, longBreakTimeMinutes: Int, showLongBreakCancelButton: Bool, accumulateRestTime: Bool, backgroundFiles: [BackgroundFile], stayUpLimitEnabled: Bool, stayUpLimitHour: Int, stayUpLimitMinute: Int) {
        // 记录当前计时器状态
        let wasRunning = pomodoroTimer.isRunning
        let wasPaused = pomodoroTimer.isPausedState
        
        // 更新计时器设置
        pomodoroTimer.updateSettings(pomodoroMinutes: pomodoroTime, breakMinutes: breakTime, idleRestart: idleRestart, idleTime: idleTime, idleActionIsRestart: idleActionIsRestart, screenLockRestart: screenLockRestart, screenLockActionIsRestart: screenLockActionIsRestart, screensaverRestart: screensaverRestart, screensaverActionIsRestart: screensaverActionIsRestart, showCancelRestButton: showCancelRestButton, longBreakCycle: longBreakCycle, longBreakTimeMinutes: longBreakTimeMinutes, showLongBreakCancelButton: showLongBreakCancelButton, accumulateRestTime: accumulateRestTime, backgroundFiles: backgroundFiles, stayUpLimitEnabled: stayUpLimitEnabled, stayUpLimitHour: stayUpLimitHour, stayUpLimitMinute: stayUpLimitMinute)
        
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
