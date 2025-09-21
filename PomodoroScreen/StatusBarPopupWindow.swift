//
//  StatusBarPopupWindow.swift
//  PomodoroScreen
//
//  Created by Assistant on 2025-09-21.
//

import Cocoa

class StatusBarPopupWindow: NSWindow {
    private var healthRingsView: HealthRingsView!
    private var menuButton: NSButton!
    private var onMenuButtonClicked: (() -> Void)?
    
    convenience init() {
        let windowSize = NSSize(width: 380, height: 280)
        
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
        
        // 初始状态隐藏
        self.alphaValue = 0.0
    }
    
    private func setupUI() {
        guard let contentView = self.contentView else { return }
        
        // 创建背景视图
        let backgroundView = NSView(frame: contentView.bounds)
        backgroundView.wantsLayer = true
        backgroundView.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.95).cgColor
        backgroundView.layer?.cornerRadius = 12
        backgroundView.layer?.borderWidth = 1
        backgroundView.layer?.borderColor = NSColor.separatorColor.cgColor
        contentView.addSubview(backgroundView)
        
        // 创建健康环视图 - 调整位置更居中
        let ringsFrame = NSRect(x: 30, y: 60, width: 160, height: 160)
        healthRingsView = HealthRingsView(frame: ringsFrame)
        contentView.addSubview(healthRingsView)
        
        // 创建右上角菜单按钮 - 调整到新的面板宽度
        menuButton = NSButton(frame: NSRect(x: 340, y: 240, width: 30, height: 30))
        menuButton.title = ""
        menuButton.image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: "菜单")
        menuButton.imagePosition = .imageOnly
        menuButton.isBordered = false
        menuButton.target = self
        menuButton.action = #selector(menuButtonClicked)
        contentView.addSubview(menuButton)
        
        // 添加标题标签 - 调整位置避免与圆环重叠
        let titleLabel = NSTextField(labelWithString: "今日状态")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = NSColor.labelColor
        titleLabel.frame = NSRect(x: 20, y: 245, width: 200, height: 20)
        contentView.addSubview(titleLabel)
        
        // 添加图例
        setupLegend(in: contentView)
    }
    
    private func setupLegend(in contentView: NSView) {
        let legendItems = [
            ("休息充足度", NSColor.restLight),      // 使用实际的气泡蓝色
            ("工作强度", NSColor.workLight),        // 使用实际的工作绿色
            ("专注度", NSColor.focusLight),         // 使用实际的专注青蓝色
            ("健康度", NSColor.healthLight)         // 使用实际的健康紫色
        ]
        
        // 调整图例位置到右侧，垂直居中
        let startX: CGFloat = 250
        let startY: CGFloat = 160
        let itemHeight: CGFloat = 20
        
        for (index, item) in legendItems.enumerated() {
            let y = startY - CGFloat(index) * itemHeight
            
            // 颜色指示器 - 调整到右侧位置
            let colorIndicator = NSView(frame: NSRect(x: startX, y: y, width: 12, height: 12))
            colorIndicator.wantsLayer = true
            colorIndicator.layer?.backgroundColor = item.1.cgColor
            colorIndicator.layer?.cornerRadius = 6
            contentView.addSubview(colorIndicator)
            
            // 标签 - 调整位置和宽度
            let label = NSTextField(labelWithString: item.0)
            label.font = NSFont.systemFont(ofSize: 11)
            label.textColor = NSColor.secondaryLabelColor
            label.frame = NSRect(x: startX + 18, y: y - 2, width: 120, height: 16)
            contentView.addSubview(label)
        }
    }
    
    @objc private func menuButtonClicked() {
        onMenuButtonClicked?()
    }
    
    func setMenuButtonAction(_ action: @escaping () -> Void) {
        onMenuButtonClicked = action
    }
    
    func updateHealthData(restAdequacy: Double, workIntensity: Double, focus: Double, health: Double) {
        healthRingsView.updateRingValues(
            outerRing: restAdequacy,
            secondRing: workIntensity,
            thirdRing: focus,
            innerRing: health
        )
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
