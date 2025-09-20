import Cocoa

class StatusBarController {
    
    // MARK: - Properties
    
    private var statusItem: NSStatusItem
    private var pomodoroTimer: PomodoroTimer
    private var settingsWindow: SettingsWindow?
    
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
        
        // 创建菜单
        let menu = NSMenu()
        
        // 开始/暂停按钮
        let startItem = NSMenuItem(title: "开始", action: #selector(startTimer), keyEquivalent: "")
        startItem.target = self
        menu.addItem(startItem)
        
        // 重置按钮
        let resetItem = NSMenuItem(title: "重置", action: #selector(resetTimer), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 立即完成按钮（用于测试遮罩层）
        let testFinishItem = NSMenuItem(title: "立即完成（测试）", action: #selector(testFinishTimer), keyEquivalent: "")
        testFinishItem.target = self
        menu.addItem(testFinishItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 设置按钮
        let settingsItem = NSMenuItem(title: "设置", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        // 退出按钮
        let quitItem = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc private func startTimer() {
        pomodoroTimer.start()
        
        // 更新菜单项标题
        if let menu = statusItem.menu,
           let startItem = menu.item(at: 0) {
            startItem.title = "停止"
            startItem.action = #selector(stopTimer)
        }
    }
    
    @objc private func stopTimer() {
        pomodoroTimer.stop()
        
        // 更新菜单项标题
        if let menu = statusItem.menu,
           let stopItem = menu.item(at: 0) {
            stopItem.title = "开始"
            stopItem.action = #selector(startTimer)
        }
    }
    
    @objc private func resetTimer() {
        pomodoroTimer.reset()
        
        // 重置菜单项
        if let menu = statusItem.menu,
           let resetItem = menu.item(at: 0) {
            resetItem.title = "开始"
            resetItem.action = #selector(startTimer)
        }
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
            
            settingsWindow?.onSettingsChanged = { [weak self] autoStart, pomodoroTime, breakTime, idleRestart, idleTime, idleActionIsRestart, screenLockRestart, screenLockActionIsRestart, screensaverRestart, screensaverActionIsRestart, showCancelRestButton, longBreakCycle, longBreakTimeMinutes, showLongBreakCancelButton, accumulateRestTime, backgroundFiles in
                self?.applySettings(autoStart: autoStart, pomodoroTime: pomodoroTime, breakTime: breakTime, idleRestart: idleRestart, idleTime: idleTime, idleActionIsRestart: idleActionIsRestart, screenLockRestart: screenLockRestart, screenLockActionIsRestart: screenLockActionIsRestart, screensaverRestart: screensaverRestart, screensaverActionIsRestart: screensaverActionIsRestart, showCancelRestButton: showCancelRestButton, longBreakCycle: longBreakCycle, longBreakTimeMinutes: longBreakTimeMinutes, showLongBreakCancelButton: showLongBreakCancelButton, accumulateRestTime: accumulateRestTime, backgroundFiles: backgroundFiles)
            }
        }
        
        settingsWindow?.showSettings()
    }
    
    private func applySettings(autoStart: Bool, pomodoroTime: Int, breakTime: Int, idleRestart: Bool, idleTime: Int, idleActionIsRestart: Bool, screenLockRestart: Bool, screenLockActionIsRestart: Bool, screensaverRestart: Bool, screensaverActionIsRestart: Bool, showCancelRestButton: Bool, longBreakCycle: Int, longBreakTimeMinutes: Int, showLongBreakCancelButton: Bool, accumulateRestTime: Bool, backgroundFiles: [BackgroundFile]) {
        // 记录当前计时器状态
        let wasRunning = pomodoroTimer.isRunning
        let wasPaused = pomodoroTimer.isPausedState
        
        // 更新计时器设置
        pomodoroTimer.updateSettings(pomodoroMinutes: pomodoroTime, breakMinutes: breakTime, idleRestart: idleRestart, idleTime: idleTime, idleActionIsRestart: idleActionIsRestart, screenLockRestart: screenLockRestart, screenLockActionIsRestart: screenLockActionIsRestart, screensaverRestart: screensaverRestart, screensaverActionIsRestart: screensaverActionIsRestart, showCancelRestButton: showCancelRestButton, longBreakCycle: longBreakCycle, longBreakTimeMinutes: longBreakTimeMinutes, showLongBreakCancelButton: showLongBreakCancelButton, accumulateRestTime: accumulateRestTime, backgroundFiles: backgroundFiles)
        
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
