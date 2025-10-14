import Cocoa

class StatusBarController {
    
    // MARK: - Properties
    
    private var statusItem: NSStatusItem
    private var pomodoroTimer: PomodoroTimer
    private var settingsWindow: SettingsWindow?
    private var popupWindow: StatusBarPopupWindow?
    private var isPopupVisible = false
    private var globalEventMonitor: Any?
    private var appDeactivationObserver: Any?
    private var workspaceActivationObserver: Any?
    private var clockIconGenerator: ClockIconGenerator
    
    // 状态栏显示设置
    private var showStatusBarText: Bool = true
    
    // MARK: - Initialization
    
    init(timer: PomodoroTimer) {
        self.pomodoroTimer = timer
        self.clockIconGenerator = ClockIconGenerator()
        
        // 加载状态栏文字显示设置
        self.showStatusBarText = SettingsStore.showStatusBarText
        
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
            
            // 从状态机派生图标类型（不改变现有逻辑）
            let iconType = self.pomodoroTimer.getStatusBarIconType()
            
            // 计算总时长：休息时使用休息总时长，其他沿用现有逻辑
            let totalTimeForIcon: TimeInterval
            switch iconType {
            case .restCup:
                let breakInfo = self.pomodoroTimer.getCurrentBreakInfo()
                totalTimeForIcon = TimeInterval(breakInfo.breakMinutes * 60)
            default:
                totalTimeForIcon = self.pomodoroTimer.getTotalTime()
            }
            
            // 计算进度（0.0表示开始，1.0表示结束）
            let progress = totalTimeForIcon > 0 ? (totalTimeForIcon - remainingTime) / totalTimeForIcon : 0.0
            
            // 选择具体图标渲染（保持原有视觉）
            let clockIcon: NSImage
            switch iconType {
            case .stayUpMoon:
                // 熬夜时段：显示月亮符号图标，并将文字改为“请勿熬夜”
                let textIcon = self.clockIconGenerator.generateTextIcon(timeString: "🌙")
                clockIcon = textIcon
                self.statusItem.button?.title = self.showStatusBarText ? "请勿熬夜" : ""
                self.statusItem.button?.toolTip = "熬夜时间段：请注意休息"
                self.statusItem.button?.image = clockIcon
                self.statusItem.button?.imagePosition = .imageLeading
                self.popupWindow?.updateCountdown(time: remainingTime, title: "")
                return
            case .restCup:
                clockIcon = self.clockIconGenerator.generateClockIcon(
                    progress: progress,
                    totalTime: totalTimeForIcon,
                    remainingTime: remainingTime,
                    isPaused: false,
                    isRest: true
                )
            case .pausedBars:
                clockIcon = self.clockIconGenerator.generateClockIcon(
                    progress: progress,
                    totalTime: totalTimeForIcon,
                    remainingTime: remainingTime,
                    isPaused: true,
                    isRest: false
                )
            case .runningClock:
                clockIcon = self.clockIconGenerator.generateClockIcon(
                    progress: progress,
                    totalTime: totalTimeForIcon,
                    remainingTime: remainingTime,
                    isPaused: false,
                    isRest: false
                )
            }
            
            // 更新状态栏图标和文字
            self.statusItem.button?.image = clockIcon
            self.statusItem.button?.title = self.showStatusBarText ? "\(timeString)" : "" // 根据设置显示或隐藏文字
            self.statusItem.button?.imagePosition = .imageLeading // 图标在左，文字在右
            
            // 设置工具提示显示时间信息
            self.statusItem.button?.toolTip = "番茄钟倒计时: \(timeString)"
            
            // 同时更新健康环视图的倒计时显示
            self.popupWindow?.updateCountdown(time: remainingTime, title: "")

            // 同步强制睡眠下的控件可用性
            let controlsEnabled = !self.pomodoroTimer.isInForcedSleepState
            self.popupWindow?.setControlsEnabled(controlsEnabled)

            // 同步休息模式下的重置按钮样式与标题（避免依赖外部手动刷新）
            let isResting = self.pomodoroTimer.isInRestPeriod || self.pomodoroTimer.isRestTimerRunning
            let resetTitle = isResting ? "取消休息" : "重置"
            let style: StatusBarPopupWindow.ResetButtonStyle = isResting ? .cancelRest : .reset
            self.popupWindow?.updateResetButton(title: resetTitle, style: style)
            // 同步按钮动作：休息中 -> 取消休息；否则 -> 重置
            self.popupWindow?.setResetButtonAction { [weak self] in
                guard let self = self else { return }
                if isResting {
                    self.cancelRest()
                } else {
                    self.resetTimer()
                }
            }
        }
    }

    // MARK: - Testing Accessors (internal)
    /// 当前状态栏图标（用于测试验证）
    public func currentStatusBarImage() -> NSImage? {
        return statusItem.button?.image
    }
    
    /// 显示会议模式休息提示
    func showMeetingModeRestIndicator() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 熬夜时段：统一由 updateTime 分支渲染（月亮+请勿熬夜）
            if self.pomodoroTimer.isStayUpTime {
                self.statusItem.button?.title = "请勿熬夜"
                self.statusItem.button?.toolTip = "熬夜时间段：请注意休息"
                return
            }

            // 仅在确实处于休息期间时显示“休息时间”，否则恢复正常显示
            if self.pomodoroTimer.isInRestPeriod {
                self.statusItem.button?.title = "休息时间"
                self.statusItem.button?.toolTip = "会议模式：静默休息中"
                print("🔇 会议模式：显示休息时间提示")
            } else {
                let timeString = self.pomodoroTimer.getRemainingTimeString()
                self.updateTime(timeString)
            }
        }
    }
    
    /// 隐藏会议模式休息提示
    func hideMeetingModeRestIndicator() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 恢复正常的时间显示
            let timeString = self.pomodoroTimer.getRemainingTimeString()
            self.updateTime(timeString)
            
            print("🔇 会议模式：隐藏休息时间提示")
        }
    }
    
    private func handleMeetingModeChanged(_ isEnabled: Bool) {
        print("🔇 会议模式状态变更：\(isEnabled ? "开启" : "关闭")")
        
        // 这里可以添加其他需要的逻辑，比如立即更新计时器设置
        // 目前会议模式的状态已经保存到 UserDefaults，
        // 立即应用到计时器（无需等待完整设置刷新）
        pomodoroTimer.setMeetingMode(isEnabled)
    }
    
    /// 刷新会议模式状态（用于屏幕检测自动切换）
    func refreshMeetingModeStatus() {
        DispatchQueue.main.async { [weak self] in
            // 更新弹窗中的开关状态
            self?.popupWindow?.refreshMeetingModeSwitch()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupStatusItem() {
        guard let button = statusItem.button else { return }
        
        // 设置初始时钟图标（进度为0）
        let initialPaused = (pomodoroTimer.isRunning == false) || pomodoroTimer.isPausedState
        let initialIcon = clockIconGenerator.generateClockIcon(
            progress: 0.0,
            totalTime: 25 * 60, // 25分钟
            remainingTime: 25 * 60,
            isPaused: initialPaused
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
        
        // 设置会议模式变更事件
        popupWindow?.setMeetingModeChangedAction { [weak self] isEnabled in
            self?.handleMeetingModeChanged(isEnabled)
        }
        
        // 更新健康环数据
        updateHealthRingsData()
        
        // 初始化按钮状态
        updatePopupButtonStates()

        // 根据强制睡眠状态初始化可用性
        let controlsEnabled = !pomodoroTimer.isInForcedSleepState
        popupWindow?.setControlsEnabled(controlsEnabled)
    }
    
    @objc private func togglePopup() {
        guard popupWindow != nil else { return }
        
        if isPopupVisible {
            hidePopup()
        } else {
            showPopup()
        }
    }
    
    func showPopup() {
        guard let popup = popupWindow,
              let button = statusItem.button else { return }
        
        // 更新健康环数据
        updateHealthRingsData()
        
        // 更新按钮状态
        updatePopupButtonStates()
        
        // 更新轮数指示器
        updateRoundIndicator()
        
        // 根据计时器状态设置健康环动画
        popup.healthRingsView.setTimerRunning(pomodoroTimer.isRunning)
        
        // 更新窗口位置
        popup.updatePosition(relativeTo: button)
        
        // 显示弹出窗口
        popup.showPopup()
        isPopupVisible = true
        
        // 监听点击事件以隐藏弹出窗口 - 暂时禁用自动隐藏
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handleGlobalClick(event)
        }
        // 取消全局点击自动隐藏，避免弹窗自动消失。保留通过切换按钮或菜单显式隐藏。
        // 但当应用失去激活（切换到其他APP）时，自动隐藏弹窗。
        appDeactivationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.hidePopup()
        }

        // 兜底：前台应用切换时也隐藏（例如某些场景下 didResignActive 未触发）
        workspaceActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if NSApplication.shared.isActive == false {
                self?.hidePopup()
            }
        }
    }
    
    private func hidePopup() {
        popupWindow?.hidePopup()
        isPopupVisible = false
        
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        if let observer = appDeactivationObserver {
            NotificationCenter.default.removeObserver(observer)
            appDeactivationObserver = nil
        }
        if let wsObserver = workspaceActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wsObserver)
            workspaceActivationObserver = nil
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
        // - Running: 显示"暂停"
        // - Idle(停止但可继续): 显示"继续" 
        // - Pause: 显示"继续"
        // - Idle(全新): 显示"开始"
        var title: String
        var action: Selector
        
        if pomodoroTimer.isRunning {
            // 计时器正在运行 - 显示"暂停"
            title = "暂停"
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
        // 使用与文字高度一致的图标画布实现垂直居中
        let menuFont = NSFont.systemFont(ofSize: 13)
        // 设置标题字体（确保行高可控）
        startItem.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: menuFont,
        ])
        // 根据不同状态设置不同图标（画布高度匹配文字行高）
        if pomodoroTimer.isRunning {
            // 运行中：菜单显示“暂停”，图标与弹窗保持一致（pause.fill）
            startItem.image = makeMenuIcon("pause.fill", font: menuFont)
        } else if pomodoroTimer.canResume {
            startItem.image = makeMenuIcon("play.fill", font: menuFont)
        } else {
            startItem.image = makeMenuIcon("play.fill", font: menuFont)
        }
        if pomodoroTimer.isInForcedSleepState {
            startItem.isEnabled = false
        }
        menu.addItem(startItem)
        
        // 重置/取消休息：在休息模式下变为“取消休息”
        let isResting = pomodoroTimer.isInRestPeriod || pomodoroTimer.isRestTimerRunning
        let resetTitle = isResting ? "取消休息" : "重置"
        let resetSelector: Selector = isResting ? #selector(cancelRest) : #selector(resetTimer)
        let resetItem = NSMenuItem(title: resetTitle, action: resetSelector, keyEquivalent: "")
        resetItem.target = self
        resetItem.image = NSImage(systemSymbolName: isResting ? "xmark.circle" : "arrow.clockwise", accessibilityDescription: resetTitle)
        if pomodoroTimer.isInForcedSleepState {
            resetItem.isEnabled = false
        }
        menu.addItem(resetItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 立即完成按钮（用于测试遮罩层）
        let testFinishItem = NSMenuItem(title: "立即完成", action: #selector(testFinishTimer), keyEquivalent: "")
        testFinishItem.target = self
        testFinishItem.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "立即完成")
        if pomodoroTimer.isInForcedSleepState {
            testFinishItem.isEnabled = false
        }
        menu.addItem(testFinishItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 今日报告按钮
        let reportItem = NSMenuItem(title: "今日报告", action: #selector(showTodayReport), keyEquivalent: "r")
        reportItem.target = self
        reportItem.image = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "今日报告")
        menu.addItem(reportItem)
        
        // 查看新手引导按钮
        let onboardingItem = NSMenuItem(title: "新手引导", action: #selector(showOnboarding), keyEquivalent: "")
        onboardingItem.target = self
        onboardingItem.image = NSImage(systemSymbolName: "questionmark.circle", accessibilityDescription: "查看新手引导")
        menu.addItem(onboardingItem)
        
        // 设置按钮
        let settingsItem = NSMenuItem(title: "设置", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: "设置")
        menu.addItem(settingsItem)
        
        // 退出按钮
        let quitItem = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: "退出")
        menu.addItem(quitItem)
        
        // 在鼠标位置显示菜单
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    // 生成垂直居中的菜单图标：复用 IconRenderer
    private func makeMenuIcon(_ systemName: String, font: NSFont, horizontalPadding: CGFloat = 2) -> NSImage? {
        return IconRenderer.centeredSymbolImage(systemName: systemName, font: font, weight: .regular, horizontalPadding: horizontalPadding)
    }
    
    @objc private func startTimer() {
        pomodoroTimer.start()
        // 清除图标缓存以立即更新状态
        clockIconGenerator.clearCache()
        // 更新健康环数据
        updateHealthRingsData()
        // 更新popup按钮状态
        updatePopupButtonStates()
        // 更新轮数指示器
        updateRoundIndicator()
        // 控制健康环动画：计时器开始时展开并启动动画
        popupWindow?.healthRingsView.setTimerRunning(true)
    }
    
    @objc private func stopTimer() {
        // 在休息过程中，"停止"应表现为暂停休息，而非彻底停止到 idle
        if pomodoroTimer.isInRestPeriod || pomodoroTimer.isRestTimerRunning {
            pomodoroTimer.pause()
        } else {
            pomodoroTimer.stop()
        }
        // 清除图标缓存以立即更新状态
        clockIconGenerator.clearCache()
        // 更新健康环数据
        updateHealthRingsData()
        // 更新popup按钮状态
        updatePopupButtonStates()
        // 更新轮数指示器
        updateRoundIndicator()
        // 控制健康环动画：暂停/停止后不运行
        popupWindow?.healthRingsView.setTimerRunning(false)
    }
    
    @objc private func resetTimer() {
        pomodoroTimer.reset()
        // 清除图标缓存以立即更新状态
        clockIconGenerator.clearCache()
        // 更新健康环数据
        updateHealthRingsData()
        // 更新popup按钮状态
        updatePopupButtonStates()
        // 更新轮数指示器
        updateRoundIndicator()
        // 控制健康环动画：重置时收缩并停止动画（因为重置后计时器未运行）
        popupWindow?.healthRingsView.setTimerRunning(false)
    }
    
    @objc private func cancelRest() {
        // 用户触发取消休息
        pomodoroTimer.cancelBreak(source: "user")
        // 清除图标缓存以立即更新状态
        clockIconGenerator.clearCache()
        // 更新健康环数据
        updateHealthRingsData()
        // 更新popup按钮状态
        updatePopupButtonStates()
        // 更新轮数指示器
        updateRoundIndicator()
        // 休息取消后计时器未运行
        popupWindow?.healthRingsView.setTimerRunning(false)
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
            title = "暂停"
        } else if pomodoroTimer.canResume {
            title = "继续"
        } else {
            title = "开始"
        }
        
        popupWindow?.updateControlButtonTitle(title)
        // 在休息模式下将重置按钮样式切换为取消休息（标题可本地化）
        let isResting = pomodoroTimer.isInRestPeriod || pomodoroTimer.isRestTimerRunning
        let resetTitle = isResting ? "取消休息" : "重置"
        let style: StatusBarPopupWindow.ResetButtonStyle = isResting ? .cancelRest : .reset
        popupWindow?.updateResetButton(title: resetTitle, style: style)
        // 同步按钮可用状态：强制睡眠时禁用
        let controlsEnabled = !pomodoroTimer.isInForcedSleepState
        popupWindow?.setControlsEnabled(controlsEnabled)
    }
    
    private func updateRoundIndicator() {
        guard let popup = popupWindow else { return }
        
        let completedRounds = pomodoroTimer.getCompletedPomodoros()
        let longBreakCycle = pomodoroTimer.getLongBreakCycle()
        
        popup.updateRoundIndicator(completedRounds: completedRounds, longBreakCycle: longBreakCycle)
    }
    
    @objc private func testFinishTimer() {
        // 在休息期内：直接完成休息；否则完成番茄钟
        if pomodoroTimer.isInRestPeriod {
            pomodoroTimer.finishBreak()
        } else {
            pomodoroTimer.triggerFinish()
        }
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
                // 从 SettingsStore 获取会议模式设置
                let meetingModeEnabled = SettingsStore.meetingModeEnabled
                self?.applySettings(autoStart: autoStart, pomodoroTime: pomodoroTime, breakTime: breakTime, idleRestart: idleRestart, idleTime: idleTime, idleActionIsRestart: idleActionIsRestart, screenLockRestart: screenLockRestart, screenLockActionIsRestart: screenLockActionIsRestart, screensaverRestart: screensaverRestart, screensaverActionIsRestart: screensaverActionIsRestart, showCancelRestButton: showCancelRestButton, longBreakCycle: longBreakCycle, longBreakTimeMinutes: longBreakTimeMinutes, showLongBreakCancelButton: showLongBreakCancelButton, accumulateRestTime: accumulateRestTime, backgroundFiles: backgroundFiles, stayUpLimitEnabled: stayUpLimitEnabled, stayUpLimitHour: stayUpLimitHour, stayUpLimitMinute: stayUpLimitMinute, showStatusBarText: showStatusBarText, meetingMode: meetingModeEnabled)
            }
        }
        
        settingsWindow?.showSettings()
    }
    
    @objc private func showTodayReport() {
        pomodoroTimer.showTodayReport()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func showOnboarding() {
        // 创建并显示新手引导窗口
        let onboardingWindow = OnboardingWindow()
        
        // 设置完成回调
        onboardingWindow.setOnboardingCompletedHandler {
            print("✅ 手动查看新手引导完成")
        }
        
        // 显示引导窗口
        onboardingWindow.makeKeyAndOrderFront(nil)
        onboardingWindow.center()
        
        // 激活应用程序
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func applySettings(autoStart: Bool, pomodoroTime: Int, breakTime: Int, idleRestart: Bool, idleTime: Int, idleActionIsRestart: Bool, screenLockRestart: Bool, screenLockActionIsRestart: Bool, screensaverRestart: Bool, screensaverActionIsRestart: Bool, showCancelRestButton: Bool, longBreakCycle: Int, longBreakTimeMinutes: Int, showLongBreakCancelButton: Bool, accumulateRestTime: Bool, backgroundFiles: [BackgroundFile], stayUpLimitEnabled: Bool, stayUpLimitHour: Int, stayUpLimitMinute: Int, showStatusBarText: Bool, meetingMode: Bool) {
        // 记录当前计时器状态
        let wasRunning = pomodoroTimer.isRunning
        let wasPaused = pomodoroTimer.isPausedState
        
        // 更新计时器设置
        pomodoroTimer.updateSettings(pomodoroMinutes: pomodoroTime, breakMinutes: breakTime, idleRestart: idleRestart, idleTime: idleTime, idleActionIsRestart: idleActionIsRestart, screenLockRestart: screenLockRestart, screenLockActionIsRestart: screenLockActionIsRestart, screensaverRestart: screensaverRestart, screensaverActionIsRestart: screensaverActionIsRestart, showCancelRestButton: showCancelRestButton, longBreakCycle: longBreakCycle, longBreakTimeMinutes: longBreakTimeMinutes, showLongBreakCancelButton: showLongBreakCancelButton, accumulateRestTime: accumulateRestTime, backgroundFiles: backgroundFiles, stayUpLimitEnabled: stayUpLimitEnabled, stayUpLimitHour: stayUpLimitHour, stayUpLimitMinute: stayUpLimitMinute, meetingMode: meetingMode)
        
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
