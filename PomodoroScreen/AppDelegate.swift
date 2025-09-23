import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusBarController: StatusBarController!
    private var pomodoroTimer: PomodoroTimer!
    private var overlayWindow: OverlayWindow?
    private var screenDetectionManager: ScreenDetectionManager!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // 初始化开机自启动管理
        // 确保LaunchAtLogin的状态与UserDefaults同步
        let savedLaunchAtLoginEnabled = UserDefaults.standard.bool(forKey: "LaunchAtLoginEnabled")
        if LaunchAtLogin.shared.isEnabled != savedLaunchAtLoginEnabled {
            LaunchAtLogin.shared.isEnabled = savedLaunchAtLoginEnabled
        }
        
        // 初始化番茄钟计时器
        pomodoroTimer = PomodoroTimer()
        
        // 初始化状态栏控制器
        statusBarController = StatusBarController(timer: pomodoroTimer)
        
        // 初始化屏幕检测管理器
        screenDetectionManager = ScreenDetectionManager.shared
        setupScreenDetection()
        
        // 设置计时器完成回调
        pomodoroTimer.onTimerFinished = { [weak self] in
            guard let self = self else { return }
            
            // 如果是会议模式且处于休息期间，隐藏休息提示
            if self.pomodoroTimer.isMeetingMode() && self.pomodoroTimer.isInRestPeriod {
                self.statusBarController.hideMeetingModeRestIndicator()
            }
            
            self.showOverlay()
        }
        
        // 设置状态栏更新回调
        pomodoroTimer.onTimeUpdate = { [weak self] timeString in
            self?.statusBarController.updateTime(timeString)
        }
        
        // 加载设置并应用
        loadAndApplySettings()
        
        // 检查是否需要显示新手引导
        // 临时重置引导状态用于测试 - 生产环境需要删除这行
        // OnboardingWindow.resetOnboarding()
        showOnboardingIfNeeded()
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
        
        // 加载熬夜限制设置
        let stayUpLimitEnabled = UserDefaults.standard.bool(forKey: "StayUpLimitEnabled") // 默认为 false
        let stayUpLimitHour = UserDefaults.standard.integer(forKey: "StayUpLimitHour")
        let stayUpHour = stayUpLimitHour == 0 ? 23 : stayUpLimitHour // 默认23:00
        let stayUpLimitMinute = UserDefaults.standard.integer(forKey: "StayUpLimitMinute") // 默认为0分钟
        
        // 加载会议模式设置
        let meetingModeEnabled = UserDefaults.standard.bool(forKey: "MeetingModeEnabled") // 默认为 false
        
        // 应用设置到计时器
        pomodoroTimer.updateSettings(pomodoroMinutes: pomodoroTime, breakMinutes: breakTime, idleRestart: idleRestartEnabled, idleTime: idleTime, idleActionIsRestart: idleActionIsRestart, screenLockRestart: screenLockRestartEnabled, screenLockActionIsRestart: screenLockActionIsRestart, screensaverRestart: screensaverRestartEnabled, screensaverActionIsRestart: screensaverActionIsRestart, showCancelRestButton: showCancelRestButton, longBreakCycle: longBreakCycle, longBreakTimeMinutes: longBreakTimeMinutes, showLongBreakCancelButton: showLongBreakCancelButton, accumulateRestTime: accumulateRestTime, backgroundFiles: backgroundFiles, stayUpLimitEnabled: stayUpLimitEnabled, stayUpLimitHour: stayUpHour, stayUpLimitMinute: stayUpLimitMinute, meetingMode: meetingModeEnabled)
        
        // 如果启用自动启动，则启动计时器
        if autoStartEnabled {
            pomodoroTimer.start()
        }
    }
    
    private func showOverlay() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 检查是否为会议模式
            if self.pomodoroTimer.isMeetingMode() {
                print("🔇 会议模式：跳过遮罩层显示，进行静默休息")
                // 在状态栏显示"休息时间"提示
                self.statusBarController.showMeetingModeRestIndicator()
                return
            }
            
            // 如果遮罩窗口已经存在且可见，不要重复创建
            if let existingWindow = self.overlayWindow, existingWindow.isVisible {
                print("⚠️ Overlay window already visible, skipping duplicate creation")
                return
            }
            
            // 清理可能存在的旧窗口
            self.overlayWindow?.orderOut(nil)
            self.overlayWindow = nil
            
            // 创建新的遮罩窗口
            self.overlayWindow = OverlayWindow(timer: self.pomodoroTimer)
            self.overlayWindow?.showOverlay()
        }
    }
    
    private func showOnboardingIfNeeded() {
        // 检查是否需要显示新手引导
        if OnboardingWindow.shouldShowOnboarding() {
            DispatchQueue.main.async { [weak self] in
                let onboardingWindow = OnboardingWindow()
                
                // 设置完成回调
                onboardingWindow.setOnboardingCompletedHandler { [weak self] in
                    print("✅ 新手引导完成")
                    // 引导完成后可以执行其他操作，比如显示状态栏popup
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.statusBarController.showPopup()
                    }
                }
                
                // 显示引导窗口
                onboardingWindow.makeKeyAndOrderFront(nil)
                onboardingWindow.center()
            }
        }
    }
    
    // MARK: - Screen Detection
    
    private func setupScreenDetection() {
        // 设置屏幕变化回调
        screenDetectionManager.onScreenConfigurationChanged = { [weak self] hasExternalScreen in
            self?.handleScreenConfigurationChanged(hasExternalScreen)
        }
        
        // 初始检查屏幕状态
        if screenDetectionManager.shouldAutoEnableMeetingMode() {
            enableMeetingModeAutomatically()
        }
        
        print("📺 屏幕检测功能已启用")
    }
    
    private func handleScreenConfigurationChanged(_ hasExternalScreen: Bool) {
        print("📺 屏幕配置变化: 外部屏幕 = \(hasExternalScreen)")
        
        // 检查是否应该自动启用/关闭会议模式
        if screenDetectionManager.shouldAutoEnableMeetingMode() {
            enableMeetingModeAutomatically()
        } else {
            disableMeetingModeAutomatically()
        }
    }
    
    private func enableMeetingModeAutomatically() {
        guard screenDetectionManager.isAutoDetectionEnabled else {
            print("📺 自动检测已禁用，跳过自动启用会议模式")
            return
        }
        
        let currentMeetingMode = UserDefaults.standard.bool(forKey: "MeetingModeEnabled")
        if !currentMeetingMode {
            print("📺 检测到投屏/外接显示器，自动启用会议模式")
            UserDefaults.standard.set(true, forKey: "MeetingModeEnabled")
            UserDefaults.standard.set(true, forKey: "MeetingModeAutoEnabled") // 标记为自动启用
            
            // 通知状态栏更新会议模式状态
            statusBarController.refreshMeetingModeStatus()
        }
    }
    
    private func disableMeetingModeAutomatically() {
        // 只有当会议模式是自动启用的时候才自动关闭
        let wasAutoEnabled = UserDefaults.standard.bool(forKey: "MeetingModeAutoEnabled")
        let currentMeetingMode = UserDefaults.standard.bool(forKey: "MeetingModeEnabled")
        
        if currentMeetingMode && wasAutoEnabled {
            print("📺 投屏/外接显示器已断开，自动关闭会议模式")
            UserDefaults.standard.set(false, forKey: "MeetingModeEnabled")
            UserDefaults.standard.set(false, forKey: "MeetingModeAutoEnabled")
            
            // 通知状态栏更新会议模式状态
            statusBarController.refreshMeetingModeStatus()
        }
    }
}
