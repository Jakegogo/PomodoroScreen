//
//  IOSSwitchButton.swift
//  PomodoroScreen
//
//  Created by Assistant on 2025-09-23.
//  iOS风格的开关按钮组件
//

import Cocoa

class IOSSwitchButton: NSView {
    
    // MARK: - Properties
    
    /// 开关状态
    var isOn: Bool = false {
        didSet {
            if oldValue != isOn {
                animateToggle()
                onValueChanged?(isOn)
            }
        }
    }
    
    /// 值变化回调
    var onValueChanged: ((Bool) -> Void)?
    
    // 尺寸配置（更小的尺寸）
    private let switchWidth: CGFloat = 36
    private let switchHeight: CGFloat = 20
    private let knobSize: CGFloat = 16
    private let knobMargin: CGFloat = 2
    
    // 颜色配置 - 使用与停止按钮一样的颜色
    private let onColor = NSColor.controlAccentColor.withAlphaComponent(0.8)  // 与停止按钮相同的蓝色
    private let offColor = NSColor.controlColor.withAlphaComponent(0.5)  // 透明白色轨道背景
    private let knobColor = NSColor.white.withAlphaComponent(0.8)
    private let borderColor = NSColor.separatorColor
    
    // UI组件
    private var trackLayer: CALayer!
    private var knobLayer: CALayer!
    private var isAnimating = false
    private var isHovering = false
    
    // MARK: - Initialization
    
    override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(x: frameRect.origin.x, y: frameRect.origin.y, width: switchWidth, height: switchHeight))
        setupLayers()
        setupGestures()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
        setupGestures()
    }
    
    convenience init() {
        self.init(frame: NSRect(x: 0, y: 0, width: 36, height: 20))
    }
    
    // MARK: - Setup
    
    private func setupLayers() {
        wantsLayer = true
        layer?.masksToBounds = false
        
        // 确保能接收鼠标事件
        self.canDrawConcurrently = false
        
        // 创建轨道层
        trackLayer = CALayer()
        trackLayer.frame = bounds
        trackLayer.cornerRadius = switchHeight / 2
        trackLayer.borderWidth = 0.5
        trackLayer.borderColor = borderColor.cgColor
        trackLayer.backgroundColor = offColor.cgColor
        layer?.addSublayer(trackLayer)
        
        // 创建滑块层
        knobLayer = CALayer()
        let knobX = knobMargin
        let knobY = (switchHeight - knobSize) / 2
        knobLayer.frame = NSRect(x: knobX, y: knobY, width: knobSize, height: knobSize)
        knobLayer.cornerRadius = knobSize / 2
        knobLayer.backgroundColor = knobColor.cgColor
        knobLayer.shadowColor = NSColor.black.cgColor
        knobLayer.shadowOffset = CGSize(width: 0, height: 1)
        knobLayer.shadowRadius = 2
        knobLayer.shadowOpacity = 0.3
        layer?.addSublayer(knobLayer)
        
        updateAppearance()
    }
    
    private func setupGestures() {
        // 使用mouseDown方法处理点击，更可靠
        // 不需要额外的手势识别器
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        // 移除旧的跟踪区域
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }
        
        // 创建新的鼠标跟踪区域
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        print("🎛️ IOSSwitchButton: 创建跟踪区域 bounds: \(bounds)")
    }
    
    // MARK: - Actions
    
    /// 切换开关状态
    func toggle() {
        print("🎛️ IOSSwitchButton toggle: \(!isOn)")
        isOn.toggle()
    }
    
    /// 设置开关状态（带动画）
    func setOn(_ on: Bool, animated: Bool = true) {
        if animated {
            isOn = on
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            isOn = on
            updateAppearance()
            CATransaction.commit()
        }
    }
    
    // MARK: - Animation
    
    private func animateToggle() {
        guard !isAnimating else { return }
        isAnimating = true
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.2)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        CATransaction.setCompletionBlock { [weak self] in
            self?.isAnimating = false
        }
        
        updateAppearance()
        
        CATransaction.commit()
    }
    
    private func updateAppearance() {
        // 根据hover状态调整颜色
        let currentOnColor: NSColor
        let currentOffColor: NSColor
        let currentKnobColor: NSColor
        
        if isHovering {
            // hover时使用更明显的效果
            if isOn {
                // 开启状态：让蓝色更鲜艳
                currentOnColor = NSColor.controlAccentColor.withAlphaComponent(1.0)
                currentOffColor = offColor
            } else {
                // 关闭状态：让灰色更深
                currentOnColor = onColor
                currentOffColor = NSColor.controlColor.withAlphaComponent(0.6)
            }
            currentKnobColor = NSColor.white.withAlphaComponent(1.0)
            print("🎛️ IOSSwitchButton: hover状态 - isOn: \(isOn)")
        } else {
            currentOnColor = onColor
            currentOffColor = offColor
            currentKnobColor = knobColor
            print("🎛️ IOSSwitchButton: 正常状态")
        }
        
        // 更新轨道颜色
        trackLayer.backgroundColor = isOn ? currentOnColor.cgColor : currentOffColor.cgColor
        
        // 更新滑块颜色
        knobLayer.backgroundColor = currentKnobColor.cgColor
        
        // 更新滑块位置
        let knobX = isOn ? (switchWidth - knobSize - knobMargin) : knobMargin
        let knobY = (switchHeight - knobSize) / 2
        knobLayer.frame = NSRect(x: knobX, y: knobY, width: knobSize, height: knobSize)
    }
    
    // MARK: - Color Enhancement
    
    private func enhanceColorSaturation(_ color: NSColor, factor: CGFloat) -> NSColor {
        // 先转换到RGB颜色空间
        guard let rgbColor = color.usingColorSpace(.deviceRGB) else {
            print("🎛️ IOSSwitchButton: 无法转换颜色空间，返回原色")
            return color
        }
        
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        rgbColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // 增加饱和度和亮度，创造更明显的效果
        let enhancedSaturation = min(1.0, saturation * factor)
        let enhancedBrightness = min(1.0, brightness * 1.1) // 稍微增加亮度
        
        let enhancedColor = NSColor(hue: hue, saturation: enhancedSaturation, brightness: enhancedBrightness, alpha: alpha)
        
        print("🎛️ IOSSwitchButton: 原色 S:\(saturation) B:\(brightness) -> 增强色 S:\(enhancedSaturation) B:\(enhancedBrightness)")
        
        return enhancedColor
    }
    
    // MARK: - Mouse Events
    
    override func mouseEntered(with event: NSEvent) {
        print("🎛️ IOSSwitchButton: 鼠标进入")
        isHovering = true
        animateHoverChange()
    }
    
    override func mouseExited(with event: NSEvent) {
        print("🎛️ IOSSwitchButton: 鼠标离开")
        isHovering = false
        animateHoverChange()
    }
    
    private func animateHoverChange() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.15)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        
        updateAppearance()
        
        CATransaction.commit()
    }
    
    override func mouseDown(with event: NSEvent) {
        print("🎛️ IOSSwitchButton mouseDown triggered")
        
        // 添加按下效果
        knobLayer.transform = CATransform3DMakeScale(0.95, 0.95, 1.0)
        
        // 处理点击切换
        toggle()
        
        super.mouseDown(with: event)
    }
    
    override func mouseUp(with event: NSEvent) {
        // 恢复正常大小
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.1)
        knobLayer.transform = CATransform3DIdentity
        CATransaction.commit()
        super.mouseUp(with: event)
    }
    
    // MARK: - Accessibility
    
    override func accessibilityRole() -> NSAccessibility.Role? {
        return .checkBox
    }
    
    override func accessibilityValue() -> Any? {
        return isOn ? 1 : 0
    }
    
    override func accessibilityLabel() -> String? {
        return "会议模式开关"
    }
    
    override func accessibilityHelp() -> String? {
        return isOn ? "会议模式已开启" : "会议模式已关闭"
    }
    
    override func accessibilityPerformPress() -> Bool {
        toggle()
        return true
    }
}

// MARK: - Size Configuration

extension IOSSwitchButton {
    
    /// 紧凑尺寸的开关
    static func compactSwitch() -> IOSSwitchButton {
        let switchButton = IOSSwitchButton()
        return switchButton
    }
    
    /// 获取推荐尺寸
    static var recommendedSize: NSSize {
        return NSSize(width: 36, height: 20)
    }
}
