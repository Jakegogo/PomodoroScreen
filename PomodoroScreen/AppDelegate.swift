import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusBarController: StatusBarController!
    private var pomodoroTimer: PomodoroTimer!
    private var overlayWindow: OverlayWindow?
    private var multiScreenOverlayManager: MultiScreenOverlayManager?
    private var screenDetectionManager: ScreenDetectionManager!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // 初始化开机自启动管理
        // 确保LaunchAtLogin的状态与UserDefaults同步
        let savedLaunchAtLoginEnabled = SettingsStore.launchAtLoginEnabled
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
        multiScreenOverlayManager?.hideAllOverlays()
        multiScreenOverlayManager = nil
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    // MARK: - Private Methods
    
    private func loadAndApplySettings() {
        // 加载设置
        let autoStartEnabled = SettingsStore.autoStartEnabled
        let pomodoroTime = SettingsStore.pomodoroTimeMinutes
        let breakTime = SettingsStore.breakTimeMinutes
        let idleRestartEnabled = SettingsStore.idleRestartEnabled
        let idleTime = SettingsStore.idleTimeMinutes
        let screenLockRestartEnabled = SettingsStore.screenLockRestartEnabled
        let screenLockActionIsRestart = SettingsStore.screenLockActionIsRestart
        let screensaverRestartEnabled = SettingsStore.screensaverRestartEnabled
        let screensaverActionIsRestart = SettingsStore.screensaverActionIsRestart
        let idleActionIsRestart = SettingsStore.idleActionIsRestart
        let showCancelRestButton = SettingsStore.showCancelRestButton
        
        // 加载计划设置
        let longBreakCycle = SettingsStore.longBreakCycle
        let longBreakTimeMinutes = SettingsStore.longBreakTimeMinutes
        let showLongBreakCancelButton = SettingsStore.showLongBreakCancelButton
        let accumulateRestTime = SettingsStore.accumulateRestTime
        
        // 加载背景设置
        var backgroundFiles: [BackgroundFile] = []
        if let backgroundData = SettingsStore.backgroundFilesData,
           let loadedBackgroundFiles = try? JSONDecoder().decode([BackgroundFile].self, from: backgroundData) {
            backgroundFiles = loadedBackgroundFiles
        }
        
        // 加载熬夜限制设置
        let stayUpLimitEnabled = SettingsStore.stayUpLimitEnabled
        let stayUpHour = SettingsStore.stayUpLimitHour
        let stayUpLimitMinute = SettingsStore.stayUpLimitMinute
        
        // 加载会议模式设置
        let meetingModeEnabled = SettingsStore.meetingModeEnabled
        
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
            
            // 确保休息计时开始（用于统计与正确计数）。
            // 注意：必须在会议模式判断之前调用，以保证会议模式下也会进入休息状态（静默）。
            // 仅当休息计时器未在运行时才触发 startBreak，避免在 .restPeriod 阶段重复计数
            if !self.pomodoroTimer.isRestTimerRunning {
                self.pomodoroTimer.startBreak()
            }

            // 检查是否为会议模式（静默休息，不弹出遮罩层）
            if self.pomodoroTimer.isMeetingMode() {
                print("🔇 会议模式：跳过遮罩层显示，进行静默休息")
                // 在状态栏显示"休息时间"提示
                self.statusBarController.showMeetingModeRestIndicator()
                return
            }
            
            // 检查屏幕数量，决定使用单屏还是多屏模式
            let screenCount = NSScreen.screens.count
            
            if screenCount > 1 {
                // 多屏幕模式：使用多屏幕管理器
                print("🖥️ 检测到 \(screenCount) 个屏幕，使用多屏幕模式")
                
                // 清理单屏幕遮罩
                self.overlayWindow?.orderOut(nil)
                self.overlayWindow = nil
                
                // 创建多屏幕管理器并显示遮罩
                self.multiScreenOverlayManager = MultiScreenOverlayManager(timer: self.pomodoroTimer)
                self.multiScreenOverlayManager?.showOverlaysOnAllScreens()
                
            } else {
                // 单屏幕模式：使用原有逻辑
                print("🖥️ 单屏幕模式")
                
                // 清理多屏幕管理器
                self.multiScreenOverlayManager?.hideAllOverlays()
                self.multiScreenOverlayManager = nil
                
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
    }

#if DEBUG
    // 测试钩子：在测试中调用以触发 overlay 显示逻辑
    @objc func showOverlayForTesting() {
        showOverlay()
    }

    // 测试钩子：直接触发当前计时器的完成逻辑（走与真实一样的回调路径）
    @objc func triggerPomodoroFinishForTesting() {
        pomodoroTimer.triggerFinish()
    }

    // 测试钩子：从 UserDefaults 重新加载并应用设置（用于切换会议模式等）
    @objc func reloadSettingsForTesting() {
        loadAndApplySettings()
    }
#endif
    
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
        
        // 如果当前有遮罩层显示，需要更新多屏幕配置
        if multiScreenOverlayManager != nil {
            print("🔄 更新多屏幕遮罩配置")
            multiScreenOverlayManager?.updateOverlaysForScreenChanges()
        } else if overlayWindow?.isVisible == true {
            // 如果当前是单屏模式但现在有多个屏幕，切换到多屏模式
            let screenCount = NSScreen.screens.count
            if screenCount > 1 {
                print("🔄 从单屏模式切换到多屏模式")
                showOverlay() // 重新显示遮罩，会自动选择合适的模式
            }
        }
    }
    
    private func enableMeetingModeAutomatically() {
        guard screenDetectionManager.isAutoDetectionEnabled else {
            print("📺 自动检测已禁用，跳过自动启用会议模式")
            return
        }
        
        let currentMeetingMode = SettingsStore.meetingModeEnabled
        if !currentMeetingMode {
            print("📺 检测到投屏/外接显示器，自动启用会议模式")
            SettingsStore.meetingModeEnabled = true
            SettingsStore.meetingModeAutoEnabled = true
            
            // 通知状态栏更新会议模式状态
            statusBarController.refreshMeetingModeStatus()
        }
    }
    
    private func disableMeetingModeAutomatically() {
        // 只有当会议模式是自动启用的时候才自动关闭
        let wasAutoEnabled = SettingsStore.meetingModeAutoEnabled
        let currentMeetingMode = SettingsStore.meetingModeEnabled
        
        if currentMeetingMode && wasAutoEnabled {
            print("📺 投屏/外接显示器已断开，自动关闭会议模式")
            SettingsStore.meetingModeEnabled = false
            SettingsStore.meetingModeAutoEnabled = false
            
            // 通知状态栏更新会议模式状态
            statusBarController.refreshMeetingModeStatus()
        }
    }
}
