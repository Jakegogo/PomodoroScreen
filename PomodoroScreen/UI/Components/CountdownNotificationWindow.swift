//
//  CountdownNotificationWindow.swift
//  PomodoroScreen
//
//  Created by Assistant on 2025-09-21.
//

import Cocoa

class CountdownNotificationWindow: NSWindow {
    var messageLabel: NSTextField!
    var backgroundView: NSView!
    var closeButton: NSButton!
    
    convenience init() {
        // 获取主屏幕尺寸
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        
        // 设置窗口大小和位置（右上角，避开Dock）
        let windowWidth: CGFloat = 200
        let windowHeight: CGFloat = 45
        let margin: CGFloat = 35
        let dockWidth: CGFloat = 40  // 预估Dock宽度
        
        let windowFrame = NSRect(
            x: screenFrame.maxX - windowWidth - margin - dockWidth,
            y: screenFrame.maxY - windowHeight - margin,
            width: windowWidth,
            height: windowHeight
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
        // 设置窗口属性
        self.level = .floating  // 浮动在其他窗口之上
        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        self.hasShadow = true
        self.ignoresMouseEvents = false  // 允许鼠标点击（关闭按钮需要）
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]  // 在所有桌面显示
        
        // 初始状态隐藏
        self.alphaValue = 0.0
        self.isReleasedWhenClosed = false
    }
    
    private func setupUI() {
        // 创建背景视图
        backgroundView = NSView(frame: self.contentView!.bounds)
        backgroundView.wantsLayer = true
        backgroundView.layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.9).cgColor
        backgroundView.layer?.cornerRadius = 8
        self.contentView?.addSubview(backgroundView)
        
        // 创建消息标签（为关闭按钮留出空间）
        messageLabel = NSTextField(frame: NSRect(x: 10, y: 10, width: 150, height: 20))
        messageLabel.isEditable = false
        messageLabel.isSelectable = false
        messageLabel.isBordered = false
        messageLabel.backgroundColor = NSColor.clear
        messageLabel.textColor = NSColor.white
        messageLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        messageLabel.alignment = .center
        messageLabel.stringValue = ""
        backgroundView.addSubview(messageLabel)
        
        // 创建关闭按钮
        closeButton = NSButton(frame: NSRect(x: 170, y: 12, width: 20, height: 20))
        closeButton.title = ""
        closeButton.bezelStyle = .circular
        closeButton.isBordered = false
        closeButton.wantsLayer = true
        closeButton.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.3).cgColor
        closeButton.layer?.cornerRadius = 10
        closeButton.target = self
        closeButton.action = #selector(closeButtonClicked)
        
        // 设置关闭按钮图标
        if let closeImage = NSImage(systemSymbolName: "xmark", accessibilityDescription: "关闭") {
            closeImage.isTemplate = true
            closeButton.image = closeImage
            closeButton.contentTintColor = NSColor.white
        } else {
            closeButton.title = "×"
            closeButton.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        }
        
        backgroundView.addSubview(closeButton)
    }
    
    // 显示30秒警告
    func showWarning() {
        messageLabel.stringValue = "即将进入休息时间"
        showWithAnimation()
    }
    
    // 显示倒计时
    func showCountdown(_ seconds: Int) {
        messageLabel.stringValue = "休息倒计时: \(seconds)秒"
        
        // 如果窗口还没显示，先显示
        if alphaValue == 0.0 {
            showWithAnimation()
        }
    }
    
    // 隐藏窗口
    func hideNotification() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 0.0
        }) {
            self.orderOut(nil)
        }
    }
    
    func showWithAnimation() {
        self.orderFront(nil)
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0.85  // 半透明效果
        })
    }
    
    // 更新窗口位置（当屏幕配置改变时）
    func updatePosition() {
        guard let screenFrame = NSScreen.main?.frame else { return }
        
        let windowWidth: CGFloat = 200
        let windowHeight: CGFloat = 40
        let margin: CGFloat = 24
        let dockWidth: CGFloat = 60  // 预估Dock宽度
        
        let newFrame = NSRect(
            x: screenFrame.maxX - windowWidth - margin - dockWidth,
            y: screenFrame.maxY - windowHeight - margin,
            width: windowWidth,
            height: windowHeight
        )
        
        self.setFrame(newFrame, display: true, animate: false)
    }
    
    // MARK: - Actions
    
    @objc private func closeButtonClicked() {
        print("🔔 用户手动关闭倒计时通知")
        hideNotification()
    }
}
