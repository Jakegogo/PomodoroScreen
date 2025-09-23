//
//  StatusBarPopupWindow.swift
//  PomodoroScreen
//
//  Created by Assistant on 2025-09-21.
//  Modified by Assistant on 2025-09-22.
//

import Cocoa

class StatusBarPopupWindow: NSWindow {
    // MARK: - UI Components
    internal var healthRingsView: HealthRingsView!
    private var menuButton: NSButton!
    private var controlButton: HoverButton!  // 开始/停止/继续按钮
    private var resetButton: HoverButton!    // 重置按钮
    private var titleLabel: NSTextField!
    private var backgroundView: NSVisualEffectView!
    private var roundIndicatorView: RoundIndicatorView!  // 轮数指示器
    
    // MARK: - Callbacks
    private var onMenuButtonClicked: (() -> Void)?
    private var onControlButtonClicked: (() -> Void)?  // 控制按钮回调
    private var onResetButtonClicked: (() -> Void)?    // 重置按钮回调
    private var onHealthRingsClicked: (() -> Void)?    // 健康环点击回调
    
    // MARK: - Constants
    private static let legendItems: [(String, NSColor)] = [
        ("休息充足度", NSColor.restLight),
        ("工作强度", NSColor.workLight),
        ("专注度", NSColor.focusLight),
        ("健康度", NSColor.healthLight)
    ]
    
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
        
        // 优化的位置计算（自适应、可读性更强）
        // 顶部区域：标题与右上角菜单按钮
        // Title 顶部不留白（紧贴窗口顶部）
        var titleY: CGFloat { windowHeight - titleHeight - titlePadding }
        var menuButtonX: CGFloat { windowWidth - menuButtonSize - horizontalPadding/2 }
        var menuButtonY: CGFloat { windowHeight - menuButtonSize - verticalPadding/2 }

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

        // 内容块（健康环 + 指示器 + 按钮 + 图例）的总高度
        private var contentBlockHeight: CGFloat {
            return healthRingSize + spacingRingToButtons + roundIndicatorHeight + spacingIndicatorToButtons + buttonHeight + spacingButtonsToLegend + legendTotalHeight
        }

        // 使内容块在内容区内垂直居中，略微上移（45%/55%分配）
        private var contentBaseY: CGFloat {
            let freeSpace = max(0, contentAreaHeight - contentBlockHeight)
            // 更少的底部留白：将可用空白的25%放在下方、75%在上方
            return contentAreaBottomY + freeSpace * 0.25
        }

        // 健康环水平居中
        var healthRingX: CGFloat { (windowWidth - healthRingSize) / 2 }

        // 分别计算每一块的底部/顶部位置，避免魔法数
        var legendTopY: CGFloat { contentBaseY + legendTotalHeight - legendItemHeight }
        var buttonY: CGFloat { contentBaseY + legendTotalHeight + spacingButtonsToLegend } // 按钮底部Y
        var roundIndicatorY: CGFloat { buttonY + buttonHeight + spacingIndicatorToButtons } // 指示器底部Y
        var healthRingY: CGFloat { roundIndicatorY + roundIndicatorHeight + spacingRingToButtons + buttonHeight } // 健康环底部Y

        // 按钮水平位置
        var controlButtonX: CGFloat { horizontalPadding }
        var resetButtonX: CGFloat { horizontalPadding + buttonWidth + horizontalSpacing }
        
        // 轮数指示器水平居中
        var roundIndicatorX: CGFloat { (windowWidth - roundIndicatorWidth) / 2 }

        // 图例首行基准Y（第一行的定位基准）
        var legendStartY: CGFloat { legendTopY }
        
        var legendX: CGFloat {
            // 动态计算图例宽度并居中
            let legendWidth: CGFloat = 120 // 图例文字大概宽度
            return (windowWidth - legendWidth) / 2
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
    }
    
    // MARK: - Legend Creation Helper
    private func createLegendElements(in contentView: NSView) {
        let startX = layoutConfig.legendX
        let startY = layoutConfig.legendStartY
        let itemHeight = layoutConfig.legendItemHeight + layoutConfig.legendSpacing
        
        for (index, item) in Self.legendItems.enumerated() {
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
                frame: NSRect(x: startX + 20, y: y - 2, width: 180, height: 22)
            )
            contentView.addSubview(label)
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
    
    @objc private func menuButtonClicked() {
        onMenuButtonClicked?()
    }
    
    @objc private func controlButtonClicked() {
        onControlButtonClicked?()
    }
    
    @objc private func resetButtonClicked() {
        onResetButtonClicked?()
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
    
    func updateControlButtonTitle(_ title: String) {
        controlButton?.title = title
        updateControlButtonIcon(for: title)
    }
    
    private func updateControlButtonIcon(for title: String) {
        let symbolName: String
        
        switch title {
        case "开始":
            symbolName = "play.fill"
        case "停止":
            symbolName = "stop.fill"
        case "继续":
            symbolName = "play.fill"
        default:
            symbolName = "play.fill"
        }
        
        controlButton?.setIcon(symbolName)
    }
    
    func updateHealthData(restAdequacy: Double, workIntensity: Double, focus: Double, health: Double) {
        healthRingsView.updateRingValues(
            outerRing: restAdequacy,
            secondRing: workIntensity,
            thirdRing: focus,
            innerRing: health
        )
    }
    
    func updateCountdown(time: TimeInterval, title: String) {
        healthRingsView.updateCountdown(time: time, title: title)
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
            if subview.identifier?.rawValue == "legend-color" || subview.identifier?.rawValue == "legend-label" {
                subview.removeFromSuperview()
            }
        }
    }
}

