//
//  ShutdownConfirmationWindow.swift
//  PomodoroScreen
//
//  Created by Assistant on 2025-09-27.
//

import Cocoa

class ShutdownConfirmationWindow: NSWindow {
    
    // MARK: - Properties
    
    private var backgroundView: NSView!
    private var titleLabel: NSTextField!
    private var messageLabel: NSTextField!
    private var confirmButton: NSButton!
    private var cancelButton: NSButton!
    
    // 回调闭包
    var onConfirm: (() -> Void)?
    var onCancel: (() -> Void)?
    
    // MARK: - Initialization
    
    convenience init() {
        let windowWidth: CGFloat = 400
        let windowHeight: CGFloat = 200
        
        // 获取主屏幕中心位置
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let windowFrame = NSRect(
            x: screenFrame.midX - windowWidth / 2,
            y: screenFrame.midY - windowHeight / 2,
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
    
    // MARK: - Setup Methods
    
    private func setupWindow() {
        // 设置窗口层级高于遮罩层
        self.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 100)  // 高于 .screenSaver (1000)
        
        // 窗口属性
        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        self.hasShadow = true
        self.isMovable = false
        self.isRestorable = false
        
        // 窗口焦点属性通过重写方法实现
        
        // 窗口行为
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
        
        // 初始状态为不可见
        self.alphaValue = 0.0
    }
    
    private func setupUI() {
        // 创建背景视图
        backgroundView = NSView(frame: self.contentView!.bounds)
        backgroundView.wantsLayer = true
        backgroundView.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.95).cgColor
        backgroundView.layer?.cornerRadius = 12
        backgroundView.layer?.borderWidth = 1
        backgroundView.layer?.borderColor = NSColor.separatorColor.cgColor
        
        // 添加阴影
        backgroundView.layer?.shadowColor = NSColor.black.cgColor
        backgroundView.layer?.shadowOffset = NSSize(width: 0, height: -4)
        backgroundView.layer?.shadowRadius = 12
        backgroundView.layer?.shadowOpacity = 0.3
        
        self.contentView?.addSubview(backgroundView)
        
        setupLabels()
        setupButtons()
        setupConstraints()
    }
    
    private func setupLabels() {
        // 标题标签
        titleLabel = NSTextField()
        titleLabel.stringValue = "确认关机"
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.isBordered = false
        titleLabel.backgroundColor = NSColor.clear
        titleLabel.textColor = NSColor.labelColor
        titleLabel.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.alignment = .center
        
        // 消息标签
        messageLabel = NSTextField()
        messageLabel.stringValue = "您确定要关闭电脑吗？\n这将结束当前的强制睡眠状态。"
        messageLabel.isEditable = false
        messageLabel.isSelectable = false
        messageLabel.isBordered = false
        messageLabel.backgroundColor = NSColor.clear
        messageLabel.textColor = NSColor.secondaryLabelColor
        messageLabel.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        messageLabel.alignment = .center
        messageLabel.maximumNumberOfLines = 0
        messageLabel.lineBreakMode = .byWordWrapping
        
        backgroundView.addSubview(titleLabel)
        backgroundView.addSubview(messageLabel)
    }
    
    private func setupButtons() {
        // 确认按钮（关机）
        confirmButton = NSButton()
        confirmButton.title = "关机"
        confirmButton.bezelStyle = .shadowlessSquare  // 使用无阴影方形样式便于自定义
        confirmButton.isBordered = false  // 移除默认边框
        confirmButton.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        confirmButton.target = self
        confirmButton.action = #selector(confirmButtonClicked)
        confirmButton.keyEquivalent = "\r" // Enter键
        
        // 设置为危险操作样式
        confirmButton.hasDestructiveAction = true
        confirmButton.wantsLayer = true
        
        // 设置按钮外观
        if #available(macOS 10.14, *) {
            confirmButton.layer?.backgroundColor = NSColor.systemRed.cgColor
        } else {
            confirmButton.layer?.backgroundColor = NSColor.red.cgColor
        }
        confirmButton.layer?.cornerRadius = 6
        confirmButton.layer?.borderWidth = 0
        
        // 设置文字颜色为白色
        confirmButton.contentTintColor = NSColor.white
        
        // 使用属性字符串确保文字为白色
        let whiteTextAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: 14, weight: .medium)
        ]
        confirmButton.attributedTitle = NSAttributedString(string: "关机", attributes: whiteTextAttributes)
        
        // 取消按钮
        cancelButton = NSButton()
        cancelButton.title = "取消"
        cancelButton.bezelStyle = .shadowlessSquare  // 使用无阴影方形样式便于自定义
        cancelButton.isBordered = false  // 移除默认边框
        cancelButton.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        cancelButton.target = self
        cancelButton.action = #selector(cancelButtonClicked)
        cancelButton.keyEquivalent = "\u{1b}" // ESC键
        
        // 设置按钮外观（不设置背景色，保持透明）
        cancelButton.wantsLayer = true
        cancelButton.layer?.cornerRadius = 6
        cancelButton.layer?.borderWidth = 1
        cancelButton.layer?.borderColor = NSColor.separatorColor.cgColor
        
        // 设置文字颜色为系统标签颜色
        let normalTextAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.labelColor,
            .font: NSFont.systemFont(ofSize: 14, weight: .regular)
        ]
        cancelButton.attributedTitle = NSAttributedString(string: "取消", attributes: normalTextAttributes)
        
        backgroundView.addSubview(confirmButton)
        backgroundView.addSubview(cancelButton)
    }
    
    private func setupConstraints() {
        // 禁用自动约束转换
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 标题标签
            titleLabel.topAnchor.constraint(equalTo: backgroundView.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor, constant: -20),
            
            // 消息标签
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            messageLabel.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor, constant: -20),
            
            // 按钮
            cancelButton.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor, constant: -20),
            cancelButton.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: 20),
            cancelButton.widthAnchor.constraint(equalToConstant: 80),
            cancelButton.heightAnchor.constraint(equalToConstant: 32),
            
            confirmButton.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor, constant: -20),
            confirmButton.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor, constant: -20),
            confirmButton.widthAnchor.constraint(equalToConstant: 80),
            confirmButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    // MARK: - Public Methods
    
    func showWithAnimation() {
        // 显示窗口
        makeKeyAndOrderFront(nil)
        
        // 淡入动画
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1.0
        }
        
        // 获得焦点
        becomeKey()
        makeMain()
    }
    
    func hideWithAnimation(completion: (() -> Void)? = nil) {
        // 淡出动画
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0.0
        }) { [weak self] in
            self?.orderOut(nil)
            completion?()
        }
    }
    
    // MARK: - Action Methods
    
    @objc private func confirmButtonClicked() {
        hideWithAnimation { [weak self] in
            self?.onConfirm?()
        }
    }
    
    @objc private func cancelButtonClicked() {
        hideWithAnimation { [weak self] in
            self?.onCancel?()
        }
    }
    
    // MARK: - Window Overrides
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        // 处理键盘事件
        if event.keyCode == 53 { // ESC键
            cancelButtonClicked()
        } else if event.keyCode == 36 { // Enter键
            confirmButtonClicked()
        } else {
            super.keyDown(with: event)
        }
    }
}
