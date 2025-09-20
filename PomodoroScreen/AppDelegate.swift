import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusBarController: StatusBarController!
    private var pomodoroTimer: PomodoroTimer!
    private var overlayWindow: OverlayWindow?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // 初始化番茄钟计时器
        pomodoroTimer = PomodoroTimer()
        
        // 初始化状态栏控制器
        statusBarController = StatusBarController(timer: pomodoroTimer)
        
        // 设置计时器完成回调
        pomodoroTimer.onTimerFinished = { [weak self] in
            self?.showOverlay()
        }
        
        // 设置状态栏更新回调
        pomodoroTimer.onTimeUpdate = { [weak self] timeString in
            self?.statusBarController.updateTime(timeString)
        }
        
        // 加载设置并应用
        loadAndApplySettings()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // 清理资源
        pomodoroTimer.stop()
        overlayWindow = nil
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    // MARK: - Private Methods
    
    private func loadAndApplySettings() {
        // 加载设置
        let autoStartEnabled = UserDefaults.standard.bool(forKey: "AutoStartEnabled") != false // 默认为 true
        let pomodoroTimeMinutes = UserDefaults.standard.integer(forKey: "PomodoroTimeMinutes")
        let pomodoroTime = pomodoroTimeMinutes == 0 ? 25 : pomodoroTimeMinutes // 默认25分钟
        let breakTimeMinutes = UserDefaults.standard.integer(forKey: "BreakTimeMinutes")
        let breakTime = breakTimeMinutes == 0 ? 3 : breakTimeMinutes // 默认3分钟
        let idleRestartEnabled = UserDefaults.standard.bool(forKey: "IdleRestartEnabled") // 默认为 false
        let idleTimeMinutes = UserDefaults.standard.integer(forKey: "IdleTimeMinutes")
        let idleTime = idleTimeMinutes == 0 ? 10 : idleTimeMinutes // 默认10分钟
        let screenLockRestartEnabled = UserDefaults.standard.bool(forKey: "ScreenLockRestartEnabled") // 默认为 false
        let screenLockActionIsRestart = UserDefaults.standard.bool(forKey: "ScreenLockActionIsRestart") != false // 默认为 true
        let screensaverRestartEnabled = UserDefaults.standard.bool(forKey: "ScreensaverRestartEnabled") // 默认为 false
        let screensaverActionIsRestart = UserDefaults.standard.bool(forKey: "ScreensaverActionIsRestart") != false // 默认为 true
        let idleActionIsRestart = UserDefaults.standard.bool(forKey: "IdleActionIsRestart") != false // 默认为 true
        let showCancelRestButton = UserDefaults.standard.bool(forKey: "ShowCancelRestButton") != false // 默认为 true
        
        // 加载计划设置
        let longBreakCycleValue = UserDefaults.standard.integer(forKey: "LongBreakCycle")
        let longBreakCycle = longBreakCycleValue == 0 ? 2 : longBreakCycleValue // 默认2次
        let longBreakTimeMinutesValue = UserDefaults.standard.integer(forKey: "LongBreakTimeMinutes")
        let longBreakTimeMinutes = longBreakTimeMinutesValue == 0 ? 5 : longBreakTimeMinutesValue // 默认5分钟
        let showLongBreakCancelButton = UserDefaults.standard.bool(forKey: "ShowLongBreakCancelButton") != false // 默认为 true
        let accumulateRestTime = UserDefaults.standard.bool(forKey: "AccumulateRestTime") // 默认为 false
        
        // 加载背景设置
        var backgroundFiles: [BackgroundFile] = []
        if let backgroundData = UserDefaults.standard.data(forKey: "BackgroundFiles"),
           let loadedBackgroundFiles = try? JSONDecoder().decode([BackgroundFile].self, from: backgroundData) {
            backgroundFiles = loadedBackgroundFiles
        }
        
        // 应用设置到计时器
        pomodoroTimer.updateSettings(pomodoroMinutes: pomodoroTime, breakMinutes: breakTime, idleRestart: idleRestartEnabled, idleTime: idleTime, idleActionIsRestart: idleActionIsRestart, screenLockRestart: screenLockRestartEnabled, screenLockActionIsRestart: screenLockActionIsRestart, screensaverRestart: screensaverRestartEnabled, screensaverActionIsRestart: screensaverActionIsRestart, showCancelRestButton: showCancelRestButton, longBreakCycle: longBreakCycle, longBreakTimeMinutes: longBreakTimeMinutes, showLongBreakCancelButton: showLongBreakCancelButton, accumulateRestTime: accumulateRestTime, backgroundFiles: backgroundFiles)
        
        // 如果启用自动启动，则启动计时器
        if autoStartEnabled {
            pomodoroTimer.start()
        }
    }
    
    private func showOverlay() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.overlayWindow = OverlayWindow(timer: self.pomodoroTimer)
            self.overlayWindow?.showOverlay()
        }
    }
}
