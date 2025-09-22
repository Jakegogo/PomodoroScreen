//
//  StatusBarPopupWindow.swift
//  PomodoroScreen
//
//  Created by Assistant on 2025-09-21.
//  Modified by Assistant on 2025-09-22.
//

import Cocoa

class StatusBarPopupWindow: NSWindow {
    private var healthRingsView: HealthRingsView!
    private var menuButton: NSButton!
    private var controlButton: HoverButton!  // 开始/停止/继续按钮
    private var resetButton: HoverButton!    // 重置按钮
    private var onMenuButtonClicked: (() -> Void)?
    private var onControlButtonClicked: (() -> Void)?  // 控制按钮回调
    private var onResetButtonClicked: (() -> Void)?    // 重置按钮回调
    private var onHealthRingsClicked: (() -> Void)?    // 健康环点击回调
    
    convenience init() {
        // 竖直布局：增加窗口高度以容纳控制按钮
        let windowSize = NSSize(width: 300, height: 500)
        
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
        
        setupWindow()
        setupUI()
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
        
        // 创建背景视图
        let backgroundView = NSView(frame: contentView.bounds)
        backgroundView.wantsLayer = true
        backgroundView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        backgroundView.layer?.cornerRadius = 12
        backgroundView.layer?.borderWidth = 1
        backgroundView.layer?.borderColor = NSColor.separatorColor.cgColor
        contentView.addSubview(backgroundView)
        
        // 竖直布局 - 标题在顶部
        let titleLabel = NSTextField(labelWithString: "番茄钟")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = NSColor.labelColor
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 20, y: 460, width: 260, height: 25)
        contentView.addSubview(titleLabel)
        
        // 右上角菜单按钮 - 适配新的窗口高度
        menuButton = NSButton(frame: NSRect(x: 255, y: 455, width: 40, height: 40))
        menuButton.title = ""
        
        // 创建更大的系统符号图标
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let menuImage = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: "菜单")?.withSymbolConfiguration(symbolConfig)
        
        menuButton.image = menuImage
        menuButton.imagePosition = .imageOnly
        menuButton.isBordered = false
        menuButton.target = self
        menuButton.action = #selector(menuButtonClicked)
        contentView.addSubview(menuButton)
        
        // 健康环视图 - 在更宽的窗口中居中放置，向上调整位置
        let ringsFrame = NSRect(x: 70, y: 280, width: 160, height: 160)
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
        
        // 添加控制按钮 - 在健康环下方
        setupControlButtons(in: contentView)
        
        // 添加图例 - 放在按钮下方
        setupLegend(in: contentView)
    }
    
    private func setupControlButtons(in contentView: NSView) {
        // 控制按钮（开始/停止/继续）- 左侧，主要按钮样式
        controlButton = HoverButton(frame: NSRect(x: 50, y: 200, width: 90, height: 40))
        controlButton.configurePrimaryStyle(title: "开始")
        controlButton.setIcon("play.fill")
        controlButton.target = self
        controlButton.action = #selector(controlButtonClicked)
        contentView.addSubview(controlButton)
        
        // 重置按钮 - 右侧，次要按钮样式
        resetButton = HoverButton(frame: NSRect(x: 160, y: 200, width: 90, height: 40))
        resetButton.configureSecondaryStyle(title: "重置")
        resetButton.setIcon("arrow.counterclockwise")
        resetButton.target = self
        resetButton.action = #selector(resetButtonClicked)
        contentView.addSubview(resetButton)
    }
    
    private func setupLegend(in contentView: NSView) {
        let legendItems = [
            ("休息充足度", NSColor.restLight),      // 使用实际的气泡蓝色
            ("工作强度", NSColor.workLight),        // 使用实际的工作绿色
            ("专注度", NSColor.focusLight),         // 使用实际的专注青蓝色
            ("健康度", NSColor.healthLight)         // 使用实际的健康紫色
        ]
        
        // 竖直布局 - 图例放在按钮下方，行间距更紧凑
        let startX: CGFloat = 100
        let startY: CGFloat = 120
        let itemHeight: CGFloat = 20
        
        for (index, item) in legendItems.enumerated() {
            let y = startY - CGFloat(index) * itemHeight
            
            // 颜色指示器 - 左侧对齐，适应紧凑行距
            let colorIndicator = NSView(frame: NSRect(x: startX, y: y + 4, width: 14, height: 14))
            colorIndicator.wantsLayer = true
            colorIndicator.layer?.backgroundColor = item.1.cgColor
            colorIndicator.layer?.cornerRadius = 7
            contentView.addSubview(colorIndicator)
            
            // 标签 - 紧跟颜色指示器，适应紧凑行距
            let label = NSTextField(labelWithString: item.0)
            label.font = NSFont.systemFont(ofSize: 12)
            label.textColor = NSColor.secondaryLabelColor
            label.frame = NSRect(x: startX + 20, y: y - 2, width: 180, height: 22)
            contentView.addSubview(label)
        }
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
    
    func setMenuButtonAction(_ action: @escaping () -> Void) {
        onMenuButtonClicked = action
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
        
        // 启动健康环动画
        healthRingsView.startBreathingAnimation()
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
}
