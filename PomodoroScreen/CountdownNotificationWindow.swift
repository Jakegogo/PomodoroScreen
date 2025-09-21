//
//  CountdownNotificationWindow.swift
//  PomodoroScreen
//
//  Created by Assistant on 2025-09-21.
//

import Cocoa

class CountdownNotificationWindow: NSWindow {
    private var messageLabel: NSTextField!
    private var backgroundView: NSView!
    
    convenience init() {
        // 获取主屏幕尺寸
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        
        // 设置窗口大小和位置（右上角，避开Dock）
        let windowWidth: CGFloat = 200
        let windowHeight: CGFloat = 60
        let margin: CGFloat = 20
        let dockWidth: CGFloat = 80  // 预估Dock宽度
        
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
        self.ignoresMouseEvents = true  // 不影响鼠标点击
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
        
        // 创建消息标签
        messageLabel = NSTextField(frame: NSRect(x: 10, y: 15, width: 180, height: 30))
        messageLabel.isEditable = false
        messageLabel.isSelectable = false
        messageLabel.isBordered = false
        messageLabel.backgroundColor = NSColor.clear
        messageLabel.textColor = NSColor.white
        messageLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        messageLabel.alignment = .center
        messageLabel.stringValue = ""
        backgroundView.addSubview(messageLabel)
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
    
    private func showWithAnimation() {
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
        let windowHeight: CGFloat = 60
        let margin: CGFloat = 20
        let dockWidth: CGFloat = 80  // 预估Dock宽度
        
        let newFrame = NSRect(
            x: screenFrame.maxX - windowWidth - margin - dockWidth,
            y: screenFrame.maxY - windowHeight - margin,
            width: windowWidth,
            height: windowHeight
        )
        
        self.setFrame(newFrame, display: true, animate: false)
    }
}
