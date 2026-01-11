//
//  StatusBarPopupWindow.swift
//  PomodoroScreen
//
//  Created by Assistant on 2025-09-21.
//  Modified by Assistant on 2025-09-22.
//

import Cocoa

class StatusBarPopupWindow: NSWindow {
    enum ResetButtonStyle {
        case reset
        case cancelRest
    }
    // MARK: - UI Components
    internal var healthRingsView: HealthRingsView!
    private var menuButton: NSButton!
    private var controlButton: HoverButton!  // 开始/停止/继续按钮
    private var resetButton: HoverButton!    // 重置按钮
    private var titleLabel: NSTextField!
    private var backgroundView: NSVisualEffectView!
    private var roundIndicatorView: RoundIndicatorView!  // 轮数指示器
    private var meetingModeSwitch: IOSSwitchButton!  // 专注模式开关
    private var meetingModeLabel: NSTextField!  // 专注模式标签
    
    // MARK: - Callbacks
    private var onMenuButtonClicked: (() -> Void)?
    private var onControlButtonClicked: (() -> Void)?  // 控制按钮回调
    private var onResetButtonClicked: (() -> Void)?    // 重置按钮回调
    private var onHealthRingsClicked: (() -> Void)?    // 健康环点击回调
    private var onMeetingModeChanged: ((Bool) -> Void)?  // 专注模式变更回调
    
    // MARK: - Constants
    // Bottom metrics (requested):
    // 完成番茄钟 / 工作时间 / 休息时间 / 健康评分
    internal static let bottomMetricItems: [(String, NSColor)] = [
        ("完成番茄钟", NSColor.workLight),
        ("工作时间", NSColor.focusLight),
        ("休息时间", NSColor.restLight),
        ("健康评分", NSColor.healthLight)
    ]
    
    // Bottom metric value views (right-side).
    private var legendValueContainers: [NSView] = []
    private var legendValueLabels: [NSTextField] = []
    private var legendValueTexts: [String] = ["0", "0h 0m", "0h 0m", "0"] // 对应 bottomMetricItems 的顺序
    
    // MARK: - Layout Configuration
    private struct LayoutConfig {
        let windowWidth: CGFloat
        let windowHeight: CGFloat
        let padding: CGFloat
        let cornerRadius: CGFloat
        
        // 响应式间距计算（分离水平与垂直边距）
        // 水平边距：决定左右留白与按钮水平起点
        var horizontalPadding: CGFloat {
            // 用户要求：基于宽度的自适应，范围 [16, 36]
            return max(16, min(48, windowWidth * 0.15))
        }
        // 垂直边距：决定顶部/底部基础留白
        var verticalPadding: CGFloat {
            // 基于高度的自适应，范围 [16, 40]
            return max(16, min(40, windowHeight * 0.05))
        }
        
        var verticalSpacing: CGFloat {
            // 根据窗口高度调整垂直间距
            return max(12, windowHeight * 0.024)
        }
        
        // 计算的布局属性
        var titleHeight: CGFloat { 25 }
        var menuButtonSize: CGFloat { 40 }
        var titlePadding: CGFloat { 15 }
        
        // 健康环大小优化 - 320px宽度特别优化
        var healthRingSize: CGFloat {
            if windowWidth <= 320 {
                return min(140, windowWidth * 0.44) // 320px时约140px
            } else {
                return min(160, windowWidth * 0.45) // 其他尺寸时稍小一些
            }
        }
        
        // 按钮尺寸优化 - 按比例小一些
        // 按钮横向间距（与左右留白分离）
        var horizontalSpacing: CGFloat { max(10, min(28, windowWidth * 0.06)) }
        var buttonWidth: CGFloat {
            // 可用宽度 = 左右padding + 两个按钮 + 中间间距
            let availableWidth = windowWidth - horizontalPadding * 2 - horizontalSpacing
            return availableWidth / 2
        }
        var buttonHeight: CGFloat {
            // 根据窗口宽度调整按钮高度，320px时更紧凑
            return windowWidth <= 320 ? 36 : 38
        }
        
        var legendItemHeight: CGFloat { 20 }
        var legendSpacing: CGFloat { 3 } // 稍微紧凑一些
        
        // 轮数指示器相关尺寸
        var roundIndicatorHeight: CGFloat { 16 }  // 指示器总高度
        var roundIndicatorWidth: CGFloat { 80 }   // 指示器总宽度
        
        // 专注模式开关相关尺寸（iOS风格）
        var meetingModeSwitchHeight: CGFloat { IOSSwitchButton.recommendedSize.height }  // 开关高度
        var meetingModeSwitchWidth: CGFloat { IOSSwitchButton.recommendedSize.width }   // 开关宽度
        var meetingModeLabelWidth: CGFloat { 60 }  // 固定标签宽度，足够显示"专注模式"
        
        // 优化的位置计算（自适应、可读性更强）
        // 顶部区域：标题与右上角菜单按钮
        // Title 顶部不留白（紧贴窗口顶部）
        var titleY: CGFloat { windowHeight - titleHeight - titlePadding }
        var menuButtonX: CGFloat { windowWidth - menuButtonSize - horizontalPadding/2 }
        // 与标题在同一水平高度：将菜单按钮在标题高度内垂直居中
        var menuButtonY: CGFloat { titleY + (titleHeight - menuButtonSize) / 2 + 2 }

        // 内容区内部通用间距（适度放宽，观感更舒适）
        var spacingAfterTitle: CGFloat { verticalSpacing * 1.3 }
        var spacingRingToButtons: CGFloat { verticalSpacing * 1.8 }
        var spacingIndicatorToButtons: CGFloat { verticalSpacing * 0.8 }  // 指示器到按钮的间距
        var spacingButtonsToLegend: CGFloat { verticalSpacing * 1.4 }

        // 图例整体高度（四行）
        var legendTotalHeight: CGFloat { legendItemHeight * 4 + legendSpacing * 3 }

        // 内容区可用高度：标题以下到底部的区域
        private var contentAreaTopY: CGFloat { windowHeight - (titleHeight + verticalPadding + spacingAfterTitle) }
        private var contentAreaBottomY: CGFloat { verticalPadding }
        private var contentAreaHeight: CGFloat { contentAreaTopY - contentAreaBottomY }

        // 内容块（健康环 + 指示器 + 按钮 + 图例 + 专注模式开关）的总高度
        private var contentBlockHeight: CGFloat {
            return healthRingSize + spacingRingToButtons + roundIndicatorHeight + spacingIndicatorToButtons + buttonHeight + spacingButtonsToLegend + legendTotalHeight + verticalSpacing + meetingModeSwitchHeight
        }

        // 使内容块在内容区内垂直居中，略微上移（45%/55%分配）
        private var contentBaseY: CGFloat {
            let freeSpace = max(0, contentAreaHeight - contentBlockHeight)
            // 更少的底部留白：将可用空白的25%放在下方、75%在上方
            return contentAreaBottomY + freeSpace * 0.25
        }

        // 健康环水平居中
        var healthRingX: CGFloat { (windowWidth - healthRingSize) / 2 }

        // 专注模式开关位置（在最底部，标签和开关作为整体居中）
        var meetingModeSwitchY: CGFloat { 
            contentBaseY - meetingModeSwitchHeight - verticalSpacing
        }
        // 计算标签和开关的总宽度
        private var meetingModeGroupWidth: CGFloat { meetingModeLabelWidth + 4 + meetingModeSwitchWidth }
        // 整体居中：以窗口中心为基准放置整个组件组
        private var meetingModeGroupX: CGFloat { (windowWidth - meetingModeGroupWidth) / 2 }
        var meetingModeSwitchX: CGFloat { meetingModeGroupX }
        var meetingModeLabelX: CGFloat { meetingModeSwitchX + meetingModeSwitchWidth + 4 }
        
        
        // 分别计算每一块的底部/顶部位置，避免魔法数
        var legendTopY: CGFloat { contentBaseY + legendTotalHeight - legendItemHeight }
        var buttonY: CGFloat { contentBaseY + legendTotalHeight + spacingButtonsToLegend } // 按钮底部Y
        var roundIndicatorY: CGFloat { buttonY + buttonHeight + spacingIndicatorToButtons } // 指示器底部Y
        var healthRingY: CGFloat { roundIndicatorY + roundIndicatorHeight + spacingRingToButtons + buttonHeight + 10 } // 健康环底部Y

        // 按钮水平位置
        var controlButtonX: CGFloat { horizontalPadding }
        var resetButtonX: CGFloat { horizontalPadding + buttonWidth + horizontalSpacing }
        
        // 轮数指示器水平居中
        var roundIndicatorX: CGFloat { (windowWidth - roundIndicatorWidth) / 2 }

        // 图例首行基准Y（第一行的定位基准）
        var legendStartY: CGFloat { legendTopY }
        
        var legendX: CGFloat {
            // 动态计算图例宽度并居中
            return (windowWidth - legendWidth) / 2
        }
        
        /// Bottom metrics width. Needs to fit Chinese values like “10小时50分钟”.
        var legendWidth: CGFloat {
            // Keep a reasonable max on narrow windows.
            return min(210, windowWidth - horizontalPadding)
        }
        
        init(width: CGFloat, height: CGFloat = 500) {
            self.windowWidth = width
            self.windowHeight = height
            self.padding = 20 // 保持基础padding用于兼容
            self.cornerRadius = 12
        }
    }
    
    private var layoutConfig: LayoutConfig!
    
    convenience init(width: CGFloat = 320, height: CGFloat = 500) {
        // 初始化布局配置
        let config = LayoutConfig(width: width, height: height)
        let windowSize = NSSize(width: config.windowWidth, height: config.windowHeight)
        
        // 获取状态栏按钮位置
        let statusBarHeight: CGFloat = 22
        let screenFrame = NSScreen.main?.frame ?? NSRect.zero
        let windowFrame = NSRect(
            x: screenFrame.maxX - windowSize.width - 20,
            y: screenFrame.maxY - statusBarHeight - windowSize.height - 10,
            width: windowSize.width,
            height: windowSize.height
        )
        
        self.init(
            contentRect: windowFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.layoutConfig = config
        setupWindow()
        setupUI()
    }
    
    // 便利构造器，保持向后兼容
    convenience init() {
        self.init(width: 320, height: 500)
    }
    
    private func setupWindow() {
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        self.hasShadow = true
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isReleasedWhenClosed = false
        
        // 确保窗口可以显示tooltip
        self.acceptsMouseMovedEvents = true
        
        // 初始状态隐藏
        self.alphaValue = 0.0
    }
    
    private func setupUI() {
        guard let contentView = self.contentView else { return }
        
        // 创建毛玻璃背景视图
        backgroundView = NSVisualEffectView(frame: contentView.bounds)
        backgroundView.material = .popover  // 轻度毛玻璃效果，性能较好
        backgroundView.blendingMode = .behindWindow
        backgroundView.state = .active
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = layoutConfig.cornerRadius
        backgroundView.layer?.borderWidth = 1
        backgroundView.layer?.borderColor = NSColor.separatorColor.cgColor
        contentView.addSubview(backgroundView)
        
        // 创建标题标签
        titleLabel = createTitleLabel()
        contentView.addSubview(titleLabel)
        
        // 创建右上角菜单按钮
        menuButton = createMenuButton()
        contentView.addSubview(menuButton)
        
        // 健康环视图
        let ringsFrame = NSRect(
            x: layoutConfig.healthRingX,
            y: layoutConfig.healthRingY,
            width: layoutConfig.healthRingSize,
            height: layoutConfig.healthRingSize
        )
        healthRingsView = HealthRingsView(frame: ringsFrame)
        
        // 设置健康环点击回调
        healthRingsView.onHealthRingsClicked = { [weak self] in
            self?.onHealthRingsClicked?()
        }
        
        contentView.addSubview(healthRingsView)
        
        // 确保健康环视图在添加到父视图后正确设置trackingArea
        DispatchQueue.main.async { [weak self] in
            self?.healthRingsView.updateTrackingAreas()
        }
        
        // 添加轮数指示器
        setupRoundIndicator(in: contentView)
        
        // 添加控制按钮
        setupControlButtons(in: contentView)
        
        // 添加专注模式开关
        setupMeetingModeSwitch(in: contentView)
        
        // 添加图例
        setupLegend(in: contentView)
    }
    
    private func setupRoundIndicator(in contentView: NSView) {
        roundIndicatorView = RoundIndicatorView(frame: NSRect(
            x: layoutConfig.roundIndicatorX,
            y: layoutConfig.roundIndicatorY,
            width: layoutConfig.roundIndicatorWidth,
            height: layoutConfig.roundIndicatorHeight
        ))
        contentView.addSubview(roundIndicatorView)
    }
    
    private func setupControlButtons(in contentView: NSView) {
        // 控制按钮（开始/停止/继续）- 左侧，主要按钮样式
        controlButton = HoverButton(frame: NSRect(
            x: layoutConfig.controlButtonX,
            y: layoutConfig.buttonY,
            width: layoutConfig.buttonWidth,
            height: layoutConfig.buttonHeight
        ))
        controlButton.configurePrimaryStyle(title: "开始")
        controlButton.setIcon("play.fill")
        controlButton.target = self
        controlButton.action = #selector(controlButtonClicked)
        contentView.addSubview(controlButton)
        
        // 重置按钮 - 右侧，次要按钮样式
        resetButton = HoverButton(frame: NSRect(
            x: layoutConfig.resetButtonX,
            y: layoutConfig.buttonY,
            width: layoutConfig.buttonWidth,
            height: layoutConfig.buttonHeight
        ))
        resetButton.configureSecondaryStyle(title: "重置")
        resetButton.setIcon("arrow.counterclockwise")
        resetButton.target = self
        resetButton.action = #selector(resetButtonClicked)
        contentView.addSubview(resetButton)
    }
    
    private func setupMeetingModeSwitch(in contentView: NSView) {
        // 创建iOS风格专注模式开关
        meetingModeSwitch = IOSSwitchButton()
        meetingModeSwitch.frame = NSRect(
            x: layoutConfig.meetingModeSwitchX,
            y: layoutConfig.meetingModeSwitchY,
            width: IOSSwitchButton.recommendedSize.width,
            height: IOSSwitchButton.recommendedSize.height
        )
        
        // 设置值变化回调
        meetingModeSwitch.onValueChanged = { [weak self] isOn in
            self?.handleMeetingModeSwitchChanged(isOn)
        }
        
        // 设置tooltip提示
        meetingModeSwitch.toolTip = "开启后，休息将静默进行，不打断你的工作，也不会遮挡屏幕。"
        
        // 创建专注模式标签
        meetingModeLabel = NSTextField(labelWithString: "专注模式")
        meetingModeLabel.frame = NSRect(
            x: layoutConfig.meetingModeLabelX,
            y: layoutConfig.meetingModeSwitchY + (IOSSwitchButton.recommendedSize.height - 16) / 2, // 垂直居中对齐
            width: layoutConfig.meetingModeLabelWidth,
            height: 16
        )
        meetingModeLabel.font = NSFont.systemFont(ofSize: 12)
        meetingModeLabel.textColor = NSColor.secondaryLabelColor
        meetingModeLabel.alignment = .left // 左对齐，文字在左侧
        
        // 为标签也设置tooltip提示
        meetingModeLabel.toolTip = "开启后，休息将静默进行，不打断你的工作，也不会遮挡屏幕。"
        
        contentView.addSubview(meetingModeSwitch)
        contentView.addSubview(meetingModeLabel)
        
        // 加载当前设置状态
        updateMeetingModeSwitch()
    }
    
    private func setupLegend(in contentView: NSView) {
        createLegendElements(in: contentView)
    }
    
    // MARK: - UI Element Creation Helpers
    private func createTitleLabel() -> NSTextField {
        let titleLabel = NSTextField(labelWithString: "番茄钟")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = NSColor.labelColor
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(
            x: layoutConfig.horizontalPadding,
            y: layoutConfig.titleY,
            width: layoutConfig.windowWidth - layoutConfig.horizontalPadding * 2,
            height: layoutConfig.titleHeight
        )
        return titleLabel
    }
    
    private func createMenuButton() -> NSButton {
        let menuButton = NSButton(frame: NSRect(
            x: layoutConfig.menuButtonX,
            y: layoutConfig.menuButtonY,
            width: layoutConfig.menuButtonSize,
            height: layoutConfig.menuButtonSize
        ))
        menuButton.title = ""
        
        // 创建系统符号图标
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let menuImage = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: "菜单")?.withSymbolConfiguration(symbolConfig)
        
        menuButton.image = menuImage
        menuButton.imagePosition = .imageOnly
        menuButton.isBordered = false
        menuButton.target = self
        menuButton.action = #selector(menuButtonClicked)
        return menuButton
    }

    /// 设置弹窗内控件的可用性（用于强制睡眠时禁用交互）
    func setControlsEnabled(_ enabled: Bool) {
        controlButton?.isEnabled = enabled
        resetButton?.isEnabled = enabled
    }

    /// 更新重置按钮（标题与样式分离，避免基于标题判断）
    func updateResetButton(title: String, style: ResetButtonStyle) {
        resetButton?.title = title
        let symbolName: String = {
            switch style {
            case .reset: return "arrow.counterclockwise"
            case .cancelRest: return "xmark.circle"
            }
        }()
        resetButton?.setIcon(symbolName)
    }
    
    private func updateUIElementFrames() {
        // 更新标题位置
        titleLabel.frame = NSRect(
            x: layoutConfig.horizontalPadding,
            y: layoutConfig.titleY,
            width: layoutConfig.windowWidth - layoutConfig.horizontalPadding * 2,
            height: layoutConfig.titleHeight
        )
        
        // 更新菜单按钮位置
        menuButton.frame = NSRect(
            x: layoutConfig.menuButtonX,
            y: layoutConfig.menuButtonY,
            width: layoutConfig.menuButtonSize,
            height: layoutConfig.menuButtonSize
        )
        
        // 更新轮数指示器位置
        roundIndicatorView.frame = NSRect(
            x: layoutConfig.roundIndicatorX,
            y: layoutConfig.roundIndicatorY,
            width: layoutConfig.roundIndicatorWidth,
            height: layoutConfig.roundIndicatorHeight
        )
        
        // 更新控制按钮位置和大小
        controlButton.frame = NSRect(
            x: layoutConfig.controlButtonX,
            y: layoutConfig.buttonY,
            width: layoutConfig.buttonWidth,
            height: layoutConfig.buttonHeight
        )
        
        resetButton.frame = NSRect(
            x: layoutConfig.resetButtonX,
            y: layoutConfig.buttonY,
            width: layoutConfig.buttonWidth,
            height: layoutConfig.buttonHeight
        )
        
        // 更新专注模式开关位置
        meetingModeSwitch.frame = NSRect(
            x: layoutConfig.meetingModeSwitchX,
            y: layoutConfig.meetingModeSwitchY,
            width: IOSSwitchButton.recommendedSize.width,
            height: IOSSwitchButton.recommendedSize.height
        )
        
        meetingModeLabel.frame = NSRect(
            x: layoutConfig.meetingModeLabelX,
            y: layoutConfig.meetingModeSwitchY + (IOSSwitchButton.recommendedSize.height - 16) / 2, // 垂直居中对齐
            width: layoutConfig.meetingModeLabelWidth,
            height: 16
        )
    }
    
    // MARK: - Legend Creation Helper
    private func createLegendElements(in contentView: NSView) {
        let startX = layoutConfig.legendX
        let startY = layoutConfig.legendStartY
        let itemHeight = layoutConfig.legendItemHeight + layoutConfig.legendSpacing
        let rowWidth: CGFloat = layoutConfig.legendWidth
        let valueWidth: CGFloat = 110
        
        // 重新创建前先清空引用，避免累积
        legendValueContainers.removeAll()
        legendValueLabels.removeAll()
        
        for (index, item) in Self.bottomMetricItems.enumerated() {
            let y = startY - CGFloat(index) * itemHeight
            
            // 创建颜色指示器
            let colorIndicator = createColorIndicator(
                frame: NSRect(x: startX, y: y + 4, width: 14, height: 14),
                color: item.1
            )
            contentView.addSubview(colorIndicator)
            
            // 创建标签
            let label = createLegendLabel(
                text: item.0,
                frame: NSRect(x: startX + 20, y: y - 2, width: rowWidth - valueWidth - 20, height: 22)
            )
            contentView.addSubview(label)
            
            // 创建右侧指标值（右对齐）
            let valueText = index < legendValueTexts.count ? legendValueTexts[index] : "-"
            let valueFrame = NSRect(x: startX + rowWidth - valueWidth, y: y - 2, width: valueWidth, height: 22)

            // Use a clipping container so we can animate "printer wheel" roll-up inside it.
            let valueContainer = NSView(frame: valueFrame)
            valueContainer.wantsLayer = true
            valueContainer.layer?.masksToBounds = true
            valueContainer.identifier = NSUserInterfaceItemIdentifier("legend-value-container-\(index)")
            contentView.addSubview(valueContainer)
            legendValueContainers.append(valueContainer)

            let valueLabel = createLegendValueLabel(text: valueText, frame: valueContainer.bounds)
            valueLabel.autoresizingMask = [.width, .height]
            valueContainer.addSubview(valueLabel)
            legendValueLabels.append(valueLabel)
        }
    }
    
    private func createColorIndicator(frame: NSRect, color: NSColor) -> NSView {
        let colorIndicator = NSView(frame: frame)
        colorIndicator.wantsLayer = true
        colorIndicator.layer?.backgroundColor = color.cgColor
        colorIndicator.layer?.cornerRadius = 7
        colorIndicator.identifier = NSUserInterfaceItemIdentifier("legend-color")
        return colorIndicator
    }
    
    private func createLegendLabel(text: String, frame: NSRect) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = NSColor.secondaryLabelColor
        label.frame = frame
        label.identifier = NSUserInterfaceItemIdentifier("legend-label")
        return label
    }
    
    private func createLegendValueLabel(text: String, frame: NSRect) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        // Use normal system font so Chinese text width is measured and rendered naturally.
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = NSColor.secondaryLabelColor
        label.alignment = .right
        label.frame = frame
        label.identifier = NSUserInterfaceItemIdentifier("legend-value")
        return label
    }
    
    @objc private func menuButtonClicked() {
        onMenuButtonClicked?()
    }
    
    @objc private func controlButtonClicked() {
        onControlButtonClicked?()
    }
    
    @objc private func resetButtonClicked() {
        onResetButtonClicked?()
    }
    
    private func handleMeetingModeSwitchChanged(_ isEnabled: Bool) {
        // 保存设置到 UserDefaults
        SettingsStore.meetingModeEnabled = isEnabled
        
        print("🔇 专注模式开关：\(isEnabled ? "开启" : "关闭")")
        
        // 通知外部需要更新计时器设置
        onMeetingModeChanged?(isEnabled)
    }
    
    // MARK: - Action Setters
    func setMenuButtonAction(_ action: @escaping () -> Void) {
        onMenuButtonClicked = action
    }
    
    func updateRoundIndicator(completedRounds: Int, longBreakCycle: Int = 2) {
        roundIndicatorView?.updateRounds(completed: completedRounds, cycle: longBreakCycle)
    }
    
    func setControlButtonAction(_ action: @escaping () -> Void) {
        onControlButtonClicked = action
    }
    
    func setResetButtonAction(_ action: @escaping () -> Void) {
        onResetButtonClicked = action
    }
    
    func setHealthRingsClickedAction(_ action: @escaping () -> Void) {
        onHealthRingsClicked = action
    }
    
    func setMeetingModeChangedAction(_ action: @escaping (Bool) -> Void) {
        onMeetingModeChanged = action
    }
    
    func updateControlButtonTitle(_ title: String) {
        controlButton?.title = title
        updateControlButtonIcon(for: title)
    }
    
    private func updateControlButtonIcon(for title: String) {
        let symbolName: String
        
        switch title {
        case "开始":
            symbolName = "play.fill"
        case "暂停":
            symbolName = "pause.fill"
        case "继续":
            symbolName = "play.fill"
        default:
            symbolName = "play.fill"
        }
        
        controlButton?.setIcon(symbolName)
    }
    
    func updateHealthData(restAdequacy: Double, workIntensity: Double, focus: Double, health: Double) {
        healthRingsView.updateRingValues(
            workIntensity: workIntensity,
            restAdequacy: restAdequacy,
            focus: focus,
            health: health
        )
    }

    func updateHealthData(restAdequacy: Double, workIntensity: Double, focus: Double, health: Double, animated: Bool, animateMask: [Bool]?) {
        healthRingsView.applyRingValues(
            workIntensity: workIntensity,
            restAdequacy: restAdequacy,
            focus: focus,
            health: health,
            animateMask: animateMask,
            animated: animated
        )
    }

    func updateBottomMetrics(completedPomodoros: Int, workTime: TimeInterval, breakTime: TimeInterval, healthScore: Double) {
        legendValueTexts = [
            Self.formatPomodoroCount(completedPomodoros),
            Self.formatDurationChinese(workTime),
            Self.formatDurationChinese(breakTime),
            Self.formatScore(healthScore)
        ]
        updateLegendValueLabels()
    }

    func updateBottomMetrics(completedPomodoros: Int, workTime: TimeInterval, breakTime: TimeInterval, healthScore: Double, animatedMask: [Bool]?) {
        legendValueTexts = [
            Self.formatPomodoroCount(completedPomodoros),
            Self.formatDurationChinese(workTime),
            Self.formatDurationChinese(breakTime),
            Self.formatScore(healthScore)
        ]
        updateLegendValueLabels(animatedMask: animatedMask)
    }

    private func updateLegendValueLabels(animatedMask: [Bool]? = nil) {
        guard !legendValueLabels.isEmpty else { return }
        let count = min(legendValueLabels.count, legendValueTexts.count)
        for i in 0..<count {
            let label = legendValueLabels[i]
            let newText = legendValueTexts[i]
            if label.stringValue == newText { continue }

            let shouldAnimate = animatedMask != nil && (i < animatedMask!.count ? animatedMask![i] : false)
            if shouldAnimate, i < legendValueContainers.count {
                animatePrinterWheelRollUp(index: i, newText: newText)
            } else {
                label.stringValue = newText
            }
        }
    }

    /// Printer-wheel roll animation: old value rolls up and out, new value rolls up from bottom into place.
    private func animatePrinterWheelRollUp(index: Int, newText: String) {
        guard index < legendValueContainers.count, index < legendValueLabels.count else { return }

        let container = legendValueContainers[index]
        let currentLabel = legendValueLabels[index]
        let oldText = currentLabel.stringValue
        if oldText == newText { return }

        let h = container.bounds.height

        // Outgoing label (snapshot)
        let outgoing = createLegendValueLabel(text: oldText, frame: container.bounds)
        outgoing.autoresizingMask = [.width, .height]

        // Incoming label starts below and rolls up into place
        let incoming = createLegendValueLabel(text: newText, frame: container.bounds.offsetBy(dx: 0, dy: -h))
        incoming.autoresizingMask = [.width, .height]

        // Clear container and add the two labels for animation
        container.subviews.forEach { $0.removeFromSuperview() }
        container.addSubview(outgoing)
        container.addSubview(incoming)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.38
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            outgoing.animator().setFrameOrigin(NSPoint(x: 0, y: h))
            incoming.animator().setFrameOrigin(NSPoint(x: 0, y: 0))
        }, completionHandler: { [weak self] in
            guard let self = self else { return }
            outgoing.removeFromSuperview()
            // Keep incoming as the canonical label reference.
            self.legendValueLabels[index] = incoming
        })
    }

    // MARK: - Bottom Metric Formatting (Chinese)
    internal static func formatDurationChinese(_ seconds: TimeInterval) -> String {
        let safeSeconds = max(0, seconds)
        let totalMinutes = Int(safeSeconds / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours == 0 {
            return "\(minutes)分钟"
        }
        if minutes == 0 {
            return "\(hours)小时"
        }
        return "\(hours)小时\(minutes)分钟"
    }
    
    internal static func formatPomodoroCount(_ count: Int) -> String {
        return "\(max(0, count)) 个"
    }
    
    internal static func formatScore(_ score: Double) -> String {
        return "\(Int(round(score)))分"
    }
    
    func updateCountdown(time: TimeInterval, title: String) {
        healthRingsView.updateCountdown(time: time, title: title)
    }
    
    private func updateMeetingModeSwitch() {
        let isEnabled = SettingsStore.meetingModeEnabled
        meetingModeSwitch.setOn(isEnabled, animated: false)
    }
    
    /// 刷新专注模式开关状态（外部调用）
    func refreshMeetingModeSwitch() {
        let isEnabled = SettingsStore.meetingModeEnabled
        meetingModeSwitch.setOn(isEnabled, animated: true) // 有动画效果
        
        // 检查是否是自动启用的
        let wasAutoEnabled = SettingsStore.meetingModeAutoEnabled
        if wasAutoEnabled {
            print("🔇 专注模式开关状态已自动更新: \(isEnabled ? "开启" : "关闭")")
        }
    }
    
    func showPopup() {
        self.orderFront(nil)
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1.0
        })
        
        // 不在这里直接启动动画，而是让StatusBarController根据计时器状态来控制
        // healthRingsView.startBreathingAnimation()
    }
    
    func hidePopup() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0.0
        }) {
            self.orderOut(nil)
            self.healthRingsView.stopBreathingAnimation()
        }
    }
    
    // 更新窗口位置（相对于状态栏按钮）
    func updatePosition(relativeTo statusBarButton: NSStatusBarButton?) {
        guard let button = statusBarButton,
              let buttonWindow = button.window else { return }
        
        let buttonFrame = buttonWindow.convertToScreen(button.frame)
        let windowSize = self.frame.size
        
        let newFrame = NSRect(
            x: buttonFrame.midX - windowSize.width / 2,
            y: buttonFrame.minY - windowSize.height - 5,
            width: windowSize.width,
            height: windowSize.height
        )
        
        self.setFrame(newFrame, display: true, animate: false)
    }
    
    // MARK: - Dynamic Layout Update
    func updateWindowSize(width: CGFloat, height: CGFloat = 500) {
        let newConfig = LayoutConfig(width: width, height: height)
        
        // 更新窗口大小和位置
        let statusBarHeight: CGFloat = 22
        let screenFrame = NSScreen.main?.frame ?? NSRect.zero
        let newFrame = NSRect(
            x: screenFrame.maxX - width - 20,
            y: screenFrame.maxY - statusBarHeight - height - 10,
            width: width,
            height: height
        )
        
        self.setFrame(newFrame, display: true, animate: true)
        self.layoutConfig = newConfig
        
        // 重新布局所有UI元素
        updateLayout()
    }
    
    private func updateLayout() {
        guard let contentView = self.contentView else { return }
        
        // 更新背景视图
        backgroundView.frame = contentView.bounds
        backgroundView.layer?.cornerRadius = layoutConfig.cornerRadius
        
        // 更新UI元素位置
        updateUIElementFrames()
        
        // 更新健康环位置和大小
        healthRingsView.frame = NSRect(
            x: layoutConfig.healthRingX,
            y: layoutConfig.healthRingY,
            width: layoutConfig.healthRingSize,
            height: layoutConfig.healthRingSize
        )
        
        // 重新创建图例（简单方法是移除旧的并重新添加）
        recreateLegend(in: contentView)
    }
    
    private func recreateLegend(in contentView: NSView) {
        // 移除现有的图例元素（通过identifier标识）
        removeLegendElements(from: contentView)
        
        // 重新创建图例
        createLegendElements(in: contentView)
    }
    
    private func removeLegendElements(from contentView: NSView) {
        contentView.subviews.forEach { subview in
            if subview.identifier?.rawValue == "legend-color"
                || subview.identifier?.rawValue == "legend-label"
                || subview.identifier?.rawValue == "legend-value" {
                subview.removeFromSuperview()
            }
        }
    }
}

