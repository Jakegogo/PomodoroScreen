//
//  HoverButton.swift
//  PomodoroScreen
//
//  Created by Assistant on 2025-09-22.
//  Modified by Assistant on 2025-09-22.
//

import Cocoa

/// 自定义按钮类，支持悬停效果和美化样式
///
/// 功能特性:
/// - 平滑的鼠标悬停颜色变化动画
/// - 支持自定义正常和悬停状态的背景色
/// - 自动处理 layer 和 tracking area 的设置
/// - 兼容 macOS 浅色/深色模式
///
/// 使用示例:
/// ```swift
/// let button = HoverButton(frame: NSRect(x: 0, y: 0, width: 100, height: 40))
/// button.title = "点击我"
/// button.setBackgroundColors(
///     normal: NSColor.controlAccentColor.cgColor,
///     hover: NSColor.controlAccentColor.withAlphaComponent(0.8).cgColor
/// )
/// ```
class HoverButton: NSButton {
    
    // MARK: - Properties
    
    private var normalBackgroundColor: CGColor?
    private var hoverBackgroundColor: CGColor?
    private var trackingArea: NSTrackingArea?
    
    // MARK: - Initialization
    
    override func awakeFromNib() {
        super.awakeFromNib()
        wantsLayer = true
        setupTrackingArea()
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupTrackingArea()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        setupTrackingArea()
    }
    
    // MARK: - Public Methods
    
    func setBackgroundColors(normal: CGColor, hover: CGColor) {
        normalBackgroundColor = normal
        hoverBackgroundColor = hover
        
        // 确保layer存在并设置初始背景色
        if let layer = layer {
            layer.backgroundColor = normal
        }
    }
    
    // MARK: - Tracking Area Management
    
    private func setupTrackingArea() {
        // 移除现有的trackingArea
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        // 使用frame尺寸而不是bounds
        let rect = NSRect(x: 0, y: 0, width: frame.width, height: frame.height)
        trackingArea = NSTrackingArea(
            rect: rect,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        setupTrackingArea()
    }
    
    // MARK: - Mouse Events
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        if let hoverColor = hoverBackgroundColor {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.allowsImplicitAnimation = true
                layer?.backgroundColor = hoverColor
            }
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if let normalColor = normalBackgroundColor {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.allowsImplicitAnimation = true
                layer?.backgroundColor = normalColor
            }
        }
    }
}

// MARK: - HoverButton Extensions

extension HoverButton {
    
    /// 配置为主要按钮样式
    /// - Parameter title: 按钮标题
    func configurePrimaryStyle(title: String) {
        self.title = title
        font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        bezelStyle = .rounded
        isBordered = false
        wantsLayer = true
        
        // 主要按钮 - 蓝色背景
        let normalColor = NSColor.controlAccentColor.withAlphaComponent(0.95).cgColor
        // 创建加浓的颜色：增加饱和度而不是加黑
        guard let rgbColor = NSColor.controlAccentColor.usingColorSpace(.deviceRGB) else {
            // 回退方案：使用完全不透明
            let hoverColor = NSColor.controlAccentColor.withAlphaComponent(1.0).cgColor
            setBackgroundColors(normal: normalColor, hover: hoverColor)
            return
        }
        
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        rgbColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // 增加饱和度让颜色更浓郁，而不是变暗
        let enhancedSaturation = min(1.0, saturation * 1.2)  // 饱和度增加20%，但不超过1.0
        let richerColor = NSColor(hue: hue, saturation: enhancedSaturation, brightness: brightness, alpha: 1.0)
        let hoverColor = richerColor.cgColor
        setBackgroundColors(normal: normalColor, hover: hoverColor)
        layer?.cornerRadius = 8
        contentTintColor = NSColor.white
        
        // 添加阴影效果
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.1
        layer?.shadowOffset = CGSize(width: 0, height: 2)
        layer?.shadowRadius = 4
    }
    
    /// 配置为次要按钮样式
    /// - Parameter title: 按钮标题
    func configureSecondaryStyle(title: String) {
        self.title = title
        font = NSFont.systemFont(ofSize: 14, weight: .medium)
        bezelStyle = .rounded
        isBordered = false
        wantsLayer = true
        
        // 次要按钮 - 灰色背景
        let normalColor = NSColor.quaternaryLabelColor.cgColor
        let hoverColor = NSColor.tertiaryLabelColor.cgColor
        setBackgroundColors(normal: normalColor, hover: hoverColor)
        layer?.cornerRadius = 8
        contentTintColor = NSColor.labelColor
        
        // 添加边框
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        
        // 添加轻微阴影
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.05
        layer?.shadowOffset = CGSize(width: 0, height: 1)
        layer?.shadowRadius = 2
    }
    
    /// 设置SF Symbol图标
    /// - Parameters:
    ///   - symbolName: SF Symbol名称
    ///   - pointSize: 图标大小
    ///   - weight: 图标粗细
    func setIcon(_ symbolName: String, pointSize: CGFloat = 12, weight: NSFont.Weight = .medium) {
        let buttonFont = self.font ?? NSFont.systemFont(ofSize: 14, weight: .regular)
        image = IconRenderer.centeredSymbolImage(systemName: symbolName, font: buttonFont, weight: weight, horizontalPadding: 1)
        imagePosition = .imageLeading
        imageHugsTitle = true
        imageScaling = .scaleNone
    }
}