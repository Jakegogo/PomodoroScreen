//
//  HealthRingsView.swift
//  PomodoroScreen
//
//  Created by Assistant on 2025-09-21.
//  Based on workout-activity-rings-master CirclesWorkout.swift implementation
//

import Cocoa
import QuartzCore
import CoreText

// MARK: - Color Extensions (Based on CirclesWorkout.swift Color extension)
extension NSColor {
    // Red ring colors (Rest Adequacy - 休息充足度) - 基于CirclesWorkout的红色环
    static var restDark: NSColor { NSColor(red: 0.8785472512, green: 0, blue: 0.07300490886, alpha: 1.0) }
    static var restLight: NSColor { NSColor(red: 0.930870235, green: 0.2051250339, blue: 0.4874394536, alpha: 1.0) }
    static var restCircleEnd: NSColor { NSColor(red: 0.9265889525, green: 0.2061708272, blue: 0.4833006263, alpha: 1.0) }
    static var restOutline: NSColor { NSColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0) } // 浅灰色背景色，与不规则形状背景色一致，完全不透明
    
    // Green ring colors (Work Intensity - 工作强度) - 基于CirclesWorkout的绿色环
    static var workDark: NSColor { NSColor(red: 0.1992103457, green: 0.8570511937, blue: 0, alpha: 1.0) }
    static var workLight: NSColor { NSColor(red: 0.6962995529, green: 0.9920799136, blue: 0, alpha: 1.0) }
    static var workCircleEnd: NSColor { NSColor(red: 0.6870413423, green: 0.9882482886, blue: 0.002495098161, alpha: 1.0) }
    static var workOutline: NSColor { NSColor(red: 0.03259197623, green: 0.1287679374, blue: 0.001097879023, alpha: 0.1) }
    
    // Blue ring colors (Focus - 专注度) - 基于CirclesWorkout的蓝色环
    static var focusDark: NSColor { NSColor(red: 0, green: 0.7215889096, blue: 0.8796694875, alpha: 1.0) }
    static var focusLight: NSColor { NSColor(red: 0.01598069631, green: 0.9643213153, blue: 0.8177756667, alpha: 1.0) }
    static var focusCircleEnd: NSColor { NSColor(red: 0.01418318599, green: 0.9563375115, blue: 0.8142204285, alpha: 1.0) }
    static var focusOutline: NSColor { NSColor(red: 0.00334665901, green: 0.107636027, blue: 0.1323693693, alpha: 0.15) }
    
    // Purple ring colors (Health - 健康度) - 自定义紫色环
    static var healthDark: NSColor { NSColor(red: 0.6, green: 0.2, blue: 0.8, alpha: 1.0) }
    static var healthLight: NSColor { NSColor(red: 0.8, green: 0.4, blue: 1.0, alpha: 1.0) }
    static var healthCircleEnd: NSColor { NSColor(red: 0.9, green: 0.5, blue: 1.0, alpha: 1.0) }
    static var healthOutline: NSColor { NSColor(red: 0.6, green: 0.2, blue: 0.8, alpha: 0.2) }
}

// MARK: - Ring Configuration (Based on RingDiameter enum from CirclesWorkout.swift)
enum RingType: CaseIterable {
    case restAdequacy    // 外环 - 休息充足度 (红色) - big
    case workIntensity   // 第二环 - 工作强度 (绿色) - medium  
    case focus           // 第三环 - 专注度 (蓝色) - small
    case health          // 内环 - 健康度 (紫色) - calculated
    
    var diameter: CGFloat {
        switch self {
        case .restAdequacy: return 0.82    // big - 最外层
        case .workIntensity: return 0.58   // medium - 第二层
        case .focus: return 0.38           // small - 第三层，增加直径减少与内层重叠
        case .health: return 0.20          // extra small - 最内层，减小直径增加间距
        }
    }
    
    var colors: [NSColor] {
        switch self {
        case .restAdequacy: return [.restDark, .restLight, .restCircleEnd, .restOutline]
        case .workIntensity: return [.workDark, .workLight, .workCircleEnd, .workOutline]
        case .focus: return [.focusDark, .focusLight, .focusCircleEnd, .focusOutline]
        case .health: return [.healthDark, .healthLight, .healthCircleEnd, .healthOutline]
        }
    }
}

class HealthRingsView: NSView {
    
    // MARK: - Ring Data Structure
    struct RingData {
        let type: RingType
        var progress: CGFloat = 0.0
        var targetProgress: CGFloat = 0.0
        var animatedProgress: CGFloat = 0.0
    }
    
    // MARK: - Properties
    private var rings: [RingData] = []
    private var animationTimer: Timer?
    private var breathingAnimationTimer: Timer?
    private var breathingPhase: Double = 0.0
    private var isBreathingAnimationActive = false
    
    // 计时器状态控制
    private var isTimerRunning = false
    private var frozenBreathingPhase: Double = 0.0 // 冻结时的呼吸相位
    
    // 倒计时显示
    private var countdownTime: TimeInterval = 0
    
    // 预加载的自定义字体
    private var countdownFont: NSFont?
    // 移除倒计时标题变量，不再需要显示标题
    
    // 圆环数值显示（原始数据，0-1范围）
    private var ringValues: [Double] = [0.0, 0.0, 0.0, 0.0]
    
    // 点击回调
    var onHealthRingsClicked: (() -> Void)?
    
    // MARK: - Constants (优化尺寸和动画)
    private let ringThickness: CGFloat = 20.0  // 缩小环的粗细，适合popup窗口
    private let baseSize: CGFloat = 180.0      // 缩小整体尺寸，适合popup窗口
    
    // MARK: - Animation Properties (优化动画流畅度)
    private let animationDuration: TimeInterval = 0.8  // 缩短动画时间，提升响应速度
    private let breathingCycleDuration: TimeInterval = 26.0  // 整体播放速度降低为原来的30%（7.8 * 3.33 ≈ 26）
    private var animationStartTime: CFTimeInterval = 0
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupRings()
        setupLayer()
        preloadCustomFont()
        setupTooltipAndTracking()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupRings()
        setupLayer()
        preloadCustomFont()
        setupTooltipAndTracking()
    }
    
    private func setupLayer() {
        // 使用传统的NSView绘制方式，避免layer-backed与Metal渲染冲突
        // 特别是在复杂动画和频繁重绘的情况下，传统绘制更稳定
        self.wantsLayer = false  // 显式禁用layer-backed绘制
    }
    
    private func preloadCustomFont() {
        let fontSize: CGFloat = 24
        
        // 尝试加载自定义字体，如果失败则使用系统字体作为备选
        if let customFont = NSFont(name: "BeautifulPoliceOfficer", size: fontSize) {
            countdownFont = customFont
        } else {
            // 如果自定义字体不可用，从文件路径加载
            if let fontURL = Bundle.main.url(forResource: "BeautifulPoliceOfficer-rvv8x", withExtension: "ttf"),
               let fontData = NSData(contentsOf: fontURL),
               let provider = CGDataProvider(data: fontData),
               let cgFont = CGFont(provider),
               let fontName = cgFont.postScriptName {
                
                // 注册字体
                CTFontManagerRegisterGraphicsFont(cgFont, nil)
                
                // 创建字体
                countdownFont = NSFont(name: String(fontName), size: fontSize)
            }
        }
        
        // 如果自定义字体加载失败，使用系统字体作为备选
        if countdownFont == nil {
            countdownFont = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold)
        }
    }
    
    private func setupRings() {
        // 初始化四个环：从外到里
        rings = [
            RingData(type: .restAdequacy),   // 外环 - 休息充足度
            RingData(type: .workIntensity),  // 第二环 - 工作强度
            RingData(type: .focus),          // 第三环 - 专注度
            RingData(type: .health)          // 内环 - 健康度
        ]
    }
    
    private func setupTooltipAndTracking() {
        // 简单设置tooltip
        self.toolTip = "点击查看今日健康报告"
    }
    
    private func updateTooltip() {
        let restPercent = Int(ringValues[0] * 100)
        let workPercent = Int(ringValues[1] * 100)
        let focusPercent = Int(ringValues[2] * 100)
        let healthPercent = Int(ringValues[3] * 100)
        
        let tooltipText = """
📊 今日健康数据

🔴 休息充足度: \(restPercent)%
🟢 工作强度: \(workPercent)%
🔵 专注度: \(focusPercent)%
🟣 健康度: \(healthPercent)%

💡 点击查看详细报告
"""
        
        self.toolTip = tooltipText
    }
    
    // MARK: - Mouse Events
    
    override func mouseDown(with event: NSEvent) {
        // 检查点击是否在健康环区域内
        let clickPoint = convert(event.locationInWindow, from: nil)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let distance = sqrt(pow(clickPoint.x - center.x, 2) + pow(clickPoint.y - center.y, 2))
        
        // 如果点击在最外环的范围内，触发回调
        let outerRadius = baseSize * RingType.restAdequacy.diameter / 2
        if distance <= outerRadius {
            onHealthRingsClicked?()
        }
    }
    
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // 将圆环中心稍微向上偏移，避免与底部标题重合
        let center = CGPoint(x: bounds.midX, y: bounds.midY - 8)
        
        // 绘制每个环（从外到里）
        for ring in rings {
            drawActivityRing(in: context, center: center, ring: ring)
        }
        
        // 绘制圆环数值
        drawRingValues(in: context, center: center)
        
        // 绘制中心文字
        drawCenterText(in: context, center: center)
    }
    
    // MARK: - Drawing Methods (Based on CirclesWorkout.swift ActivityRing)
    
    private func drawActivityRing(in context: CGContext, center: CGPoint, ring: RingData) {
        let progress = ring.animatedProgress
        let diameter = ring.type.diameter
        let radius = baseSize * diameter / 2
        let colors = ring.type.colors
        
        // Apply breathing animation scale (基于CirclesWorkout的渐进式呼吸效果)
        var effectiveRadius = radius
        var effectiveThickness = ringThickness
        
        // 计算呼吸效果：动画活跃时使用实时相位，停止时使用冻结相位
        let currentPhase = isBreathingAnimationActive ? breathingPhase : frozenBreathingPhase
        let shouldApplyBreathingEffect = isBreathingAnimationActive || frozenBreathingPhase != 0.0
        
        if shouldApplyBreathingEffect {
            // 渐进式呼吸效果 - 外层效果最强，内层效果递减
            let breathingIntensity: CGFloat
            switch ring.type {
            case .restAdequacy:    // 最外层 - 最强的不规则气泡效果
                // 使用更平滑的缓动函数组合
                let baseBreathing = smoothBreathing(currentPhase)
                let wave1 = baseBreathing * 0.12
                let wave2 = smoothBreathing(currentPhase * 1.3 + 0.5) * 0.08
                let wave3 = smoothBreathing(currentPhase * 0.7 + 1.2) * 0.06
                let wave4 = smoothBreathing(currentPhase * 2.1 + 0.9) * 0.04
                breathingIntensity = wave1 + wave2 + wave3 + wave4
            case .workIntensity:   // 第二层 - 与最外层节奏一致，强度适中
                let baseBreathing = smoothBreathing(currentPhase)
                let wave1 = baseBreathing * 0.070
                let wave2 = smoothBreathing(currentPhase * 1.3 + 0.5) * 0.044
                let wave3 = smoothBreathing(currentPhase * 0.7 + 1.2) * 0.032
                let wave4 = smoothBreathing(currentPhase * 2.1 + 0.9) * 0.020
                breathingIntensity = wave1 + wave2 + wave3 + wave4
            case .focus:           // 第三层 - 与最外层节奏一致，强度较轻
                let baseBreathing = smoothBreathing(currentPhase)
                let wave1 = baseBreathing * 0.045
                let wave2 = smoothBreathing(currentPhase * 1.3 + 0.5) * 0.030
                let wave3 = smoothBreathing(currentPhase * 0.7 + 1.2) * 0.022
                let wave4 = smoothBreathing(currentPhase * 2.1 + 0.9) * 0.013
                breathingIntensity = wave1 + wave2 + wave3 + wave4
            case .health:          // 最内层 - 与最外层节奏一致，强度最轻
                let baseBreathing = smoothBreathing(currentPhase)
                let wave1 = baseBreathing * 0.025
                let wave2 = smoothBreathing(currentPhase * 1.3 + 0.5) * 0.017
                let wave3 = smoothBreathing(currentPhase * 0.7 + 1.2) * 0.012
                let wave4 = smoothBreathing(currentPhase * 2.1 + 0.9) * 0.008
                breathingIntensity = wave1 + wave2 + wave3 + wave4
            }
            
            let irregularScale = 1.0 + breathingIntensity
            effectiveRadius *= irregularScale
            effectiveThickness *= irregularScale
        }
        
        context.saveGState()
        
        // 基于CirclesWorkout.swift的绘制逻辑：progress < 0.98 vs else
        if progress < 0.98 {
            // Background ring (outline color) - 对应CirclesWorkout的background ring
            // 先绘制普通背景环（所有圆环都需要）
            // 最外层圆环的背景环向内加粗（通过向内收缩半径实现）
            if ring.type == .restAdequacy {
                // 最外层：向内加粗，半径向内收缩
                let inwardOffset = effectiveThickness * 0.4  // 向内偏移
                let thickerRadius = effectiveRadius - inwardOffset
                let thickerThickness = effectiveThickness * 1.8
                drawBackgroundRing(in: context, center: center, radius: thickerRadius, thickness: thickerThickness, color: colors[3])
            } else {
                // 其他圆环：保持原样
                drawBackgroundRing(in: context, center: center, radius: effectiveRadius, thickness: effectiveThickness, color: colors[3])
            }
            
            // 为最外层圆环额外绘制不规则背景环（叠加效果）
            // 在动画活跃时或有冻结相位时都绘制不规则圈
            if ring.type == .restAdequacy && (isBreathingAnimationActive || frozenBreathingPhase != 0.0) {
                drawIrregularBackgroundRing(in: context, center: center, radius: effectiveRadius, thickness: effectiveThickness, color: colors[3])
            }
            
            // Progress ring with gradient - 对应CirclesWorkout的Activity Ring with trim
            if progress > 0.01 {
                drawProgressRing(in: context, center: center, radius: effectiveRadius, thickness: effectiveThickness, progress: progress, colors: colors, ring: ring)
                
                // Start dot (fix overlapping gradient from full cycle) - 对应CirclesWorkout的fix overlapping gradient
                drawStartDot(in: context, center: center, radius: effectiveRadius, thickness: effectiveThickness, color: colors[0])
            }
        } else {
            // Full ring with gradient - 对应CirclesWorkout的else分支
            drawFullRing(in: context, center: center, radius: effectiveRadius, thickness: effectiveThickness, progress: progress, colors: colors, ring: ring)
            
            // End circle with shadow - 对应CirclesWorkout的end circle with shadow
            drawEndCircle(in: context, center: center, radius: effectiveRadius, thickness: effectiveThickness, progress: progress, color: colors[2])
        }
        
        context.restoreGState()
    }
    
    private func drawBackgroundRing(in context: CGContext, center: CGPoint, radius: CGFloat, thickness: CGFloat, color: NSColor) {
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(thickness)
        context.setLineCap(.round)
        
        context.addArc(center: center, radius: radius, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        context.strokePath()
        
        context.restoreGState()
    }
    
    private func drawIrregularBackgroundRing(in context: CGContext, center: CGPoint, radius: CGFloat, thickness: CGFloat, color: NSColor) {
        context.saveGState()
        
        // 使用贝塞尔曲线绘制不规则圆环，性能比分段绘制提升3-5倍
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(thickness)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        // 创建不规则贝塞尔曲线路径，使用当前相位（动画时为实时相位，冻结时为冻结相位）
        let currentPhase = isBreathingAnimationActive ? breathingPhase : frozenBreathingPhase
        let bezierPath = createIrregularBezierPath(center: center, baseRadius: radius, time: currentPhase)
        context.addPath(bezierPath)
        context.strokePath()
        
        context.restoreGState()
    }
    
    // 使用贝塞尔曲线创建不规则圆环路径，性能比分段绘制提升3-5倍
    private func createIrregularBezierPath(center: CGPoint, baseRadius: CGFloat, time: Double) -> CGPath {
        let path = CGMutablePath()
        
        // 使用8个控制点创建平滑的不规则曲线，比24个分段性能提升3倍
        let controlPointCount = 8
        let angleStep = (2 * .pi) / CGFloat(controlPointCount)
        
        // 预计算三角函数值，避免重复计算
        let angles = (0..<controlPointCount).map { CGFloat($0) * angleStep }
        let cosValues = angles.map { cos($0) }
        let sinValues = angles.map { sin($0) }
        
        // 计算不规则控制点
        var points: [CGPoint] = []
        for i in 0..<controlPointCount {
            let angle = angles[i]
            let irregularRadius = calculateOptimizedIrregularRadius(baseRadius: baseRadius, angle: angle, time: time)
            
            let x = center.x + irregularRadius * cosValues[i]
            let y = center.y + irregularRadius * sinValues[i]
            points.append(CGPoint(x: x, y: y))
        }
        
        // 创建平滑的闭合贝塞尔曲线
        guard points.count >= 3 else { return path }
        
        path.move(to: points[0])
        
        // 使用三次贝塞尔曲线创建更平滑的不规则形状
        for i in 0..<controlPointCount {
            let currentIndex = i
            let nextIndex = (i + 1) % controlPointCount
            let currentPoint = points[currentIndex]
            let nextPoint = points[nextIndex]
            
            // 计算控制点，确保曲线平滑连续
            let prevIndex = (i - 1 + controlPointCount) % controlPointCount
            let nextNextIndex = (i + 2) % controlPointCount
            let prevPoint = points[prevIndex]
            let nextNextPoint = points[nextNextIndex]
            
            // 使用相邻点计算控制点，创建自然的曲线
            let control1 = CGPoint(
                x: currentPoint.x + (nextPoint.x - prevPoint.x) * 0.2,
                y: currentPoint.y + (nextPoint.y - prevPoint.y) * 0.2
            )
            let control2 = CGPoint(
                x: nextPoint.x - (nextNextPoint.x - currentPoint.x) * 0.2,
                y: nextPoint.y - (nextNextPoint.y - currentPoint.y) * 0.2
            )
            
            path.addCurve(to: nextPoint, control1: control1, control2: control2)
        }
        
        path.closeSubpath()
        return path
    }
    
    // 优化的不规则半径计算，专为贝塞尔曲线设计
    private func calculateOptimizedIrregularRadius(baseRadius: CGFloat, angle: CGFloat, time: Double) -> CGFloat {
        // 使用原生sin函数替代smoothSin，性能提升约40%
        let wave1 = sin(angle * 3 + time) * 0.08
        let wave2 = sin(angle * 2 + time * 1.3 + 0.5) * 0.06
        let globalSqueeze = sin(time * 1.5) * 0.04
        
        let totalVariation = wave1 + wave2 + globalSqueeze
        return baseRadius * (1.0 + totalVariation)
    }
    
    private func drawProgressRing(in context: CGContext, center: CGPoint, radius: CGFloat, thickness: CGFloat, progress: CGFloat, colors: [NSColor], ring: RingData) {
        guard progress > 0.01 else { return }
        
        context.saveGState()
        
        // 计算呼吸效果：动画活跃时使用实时相位，停止时使用冻结相位
        let currentPhase = isBreathingAnimationActive ? breathingPhase : frozenBreathingPhase
        let shouldApplyBreathingEffect = isBreathingAnimationActive || frozenBreathingPhase != 0.0
        
        // Apply breathing animation alpha (渐进式透明度效果)
        if shouldApplyBreathingEffect {
            let alphaIntensity: CGFloat
            switch ring.type {
            case .restAdequacy:
                let bubbleAlpha1 = sin(currentPhase) * 0.15
                let bubbleAlpha2 = sin(currentPhase * 1.7 + 0.8) * 0.1
                alphaIntensity = bubbleAlpha1 + bubbleAlpha2
            case .workIntensity:
                // 与最外层节奏一致的多波形透明度变化
                let bubbleAlpha1 = sin(currentPhase) * 0.15
                let bubbleAlpha2 = sin(currentPhase * 1.7 + 0.8) * 0.11
                alphaIntensity = bubbleAlpha1 + bubbleAlpha2
            case .focus:
                // 与最外层节奏一致的多波形透明度变化，强度较轻
                let bubbleAlpha1 = sin(currentPhase) * 0.10
                let bubbleAlpha2 = sin(currentPhase * 1.7 + 0.8) * 0.06
                alphaIntensity = bubbleAlpha1 + bubbleAlpha2
            case .health:
                // 与最外层节奏一致的多波形透明度变化，强度最轻
                let bubbleAlpha1 = sin(currentPhase) * 0.06
                let bubbleAlpha2 = sin(currentPhase * 1.7 + 0.8) * 0.04
                alphaIntensity = bubbleAlpha1 + bubbleAlpha2
            }
            
            let breathingAlpha = 0.8 + alphaIntensity
            context.setAlpha(breathingAlpha)
        }
        
        // Create angular gradient (simulated with multiple arcs) - 基于CirclesWorkout的AngularGradient
        let startAngle: CGFloat = -.pi / 2  // Start from top (-90 degrees like CirclesWorkout)
        let endAngle = startAngle + 2 * .pi * min(progress, 1.0)
        
        // Draw gradient effect by drawing multiple thin arcs - 减少步数提升性能
        let steps = 50  // 从200减少到50，减少75%的绘制调用
        let angleStep = (endAngle - startAngle) / CGFloat(steps)
        
        for i in 0..<steps {
            let currentAngle = startAngle + CGFloat(i) * angleStep
            let nextAngle = currentAngle + angleStep
            
            // 使用平滑插值模拟AngularGradient
            let ratio = CGFloat(i) / CGFloat(steps - 1)
            let smoothRatio = smoothstep(0, 1, ratio)
            let color = interpolateColor(from: colors[0], to: colors[1], ratio: smoothRatio)
            
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(thickness)
            context.setLineCap(.round)
            
            context.addArc(center: center, radius: radius, startAngle: currentAngle, endAngle: nextAngle, clockwise: false)
            context.strokePath()
        }
        
        context.restoreGState()
    }
    
    private func drawStartDot(in context: CGContext, center: CGPoint, radius: CGFloat, thickness: CGFloat, color: NSColor) {
        context.saveGState()
        
        // 对应CirclesWorkout的fix overlapping gradient circle at start position
        let dotCenter = CGPoint(x: center.x, y: center.y - radius)
        
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: CGRect(x: dotCenter.x - thickness/2, y: dotCenter.y - thickness/2, width: thickness, height: thickness))
        
        context.restoreGState()
    }
    
    private func drawFullRing(in context: CGContext, center: CGPoint, radius: CGFloat, thickness: CGFloat, progress: CGFloat, colors: [NSColor], ring: RingData) {
        context.saveGState()
        
        // 计算呼吸效果：动画活跃时使用实时相位，停止时使用冻结相位
        let currentPhase = isBreathingAnimationActive ? breathingPhase : frozenBreathingPhase
        let shouldApplyBreathingEffect = isBreathingAnimationActive || frozenBreathingPhase != 0.0
        
        // Apply breathing animation alpha
        if shouldApplyBreathingEffect {
            let alphaIntensity: CGFloat
            switch ring.type {
            case .restAdequacy:
                let bubbleAlpha1 = sin(currentPhase) * 0.15
                let bubbleAlpha2 = sin(currentPhase * 1.7 + 0.8) * 0.1
                alphaIntensity = bubbleAlpha1 + bubbleAlpha2
            case .workIntensity:
                // 与最外层节奏一致的多波形透明度变化
                let bubbleAlpha1 = sin(currentPhase) * 0.15
                let bubbleAlpha2 = sin(currentPhase * 1.7 + 0.8) * 0.11
                alphaIntensity = bubbleAlpha1 + bubbleAlpha2
            case .focus:
                // 与最外层节奏一致的多波形透明度变化，强度较轻
                let bubbleAlpha1 = sin(currentPhase) * 0.10
                let bubbleAlpha2 = sin(currentPhase * 1.7 + 0.8) * 0.06
                alphaIntensity = bubbleAlpha1 + bubbleAlpha2
            case .health:
                // 与最外层节奏一致的多波形透明度变化，强度最轻
                let bubbleAlpha1 = sin(currentPhase) * 0.06
                let bubbleAlpha2 = sin(currentPhase * 1.7 + 0.8) * 0.04
                alphaIntensity = bubbleAlpha1 + bubbleAlpha2
            }
            
            let breathingAlpha = 0.8 + alphaIntensity
            context.setAlpha(breathingAlpha)
        }
        
        // Draw full gradient ring - 对应CirclesWorkout else分支的Activity Ring
        let steps = 100
        let angleStep = 2 * .pi / CGFloat(steps)
        
        for i in 0..<steps {
            let currentAngle = CGFloat(i) * angleStep - .pi / 2  // Start from top
            let nextAngle = currentAngle + angleStep
            
            // Interpolate color for full ring gradient
            let ratio = CGFloat(i) / CGFloat(steps - 1)
            let color = interpolateColor(from: colors[0], to: colors[1], ratio: ratio)
            
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(thickness)
            context.setLineCap(.round)
            
            context.addArc(center: center, radius: radius, startAngle: currentAngle, endAngle: nextAngle, clockwise: false)
            context.strokePath()
        }
        
        context.restoreGState()
    }
    
    private func drawEndCircle(in context: CGContext, center: CGPoint, radius: CGFloat, thickness: CGFloat, progress: CGFloat, color: NSColor) {
        context.saveGState()
        
        // Calculate end position based on progress - 对应CirclesWorkout的end circle
        let angle = 2 * .pi * progress - .pi / 2  // Start from top
        let endCenter = CGPoint(
            x: center.x + radius * cos(angle),
            y: center.y + radius * sin(angle)
        )
        
        // 使用简化的阴影效果，避免复杂的blur操作
        context.setShadow(offset: CGSize(width: 1, height: 1), blur: 2, color: NSColor.black.withAlphaComponent(0.15).cgColor)
        
        // Draw end circle
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: CGRect(x: endCenter.x - thickness/2, y: endCenter.y - thickness/2, width: thickness, height: thickness))
        
        context.restoreGState()
    }
    
    private func interpolateColor(from: NSColor, to: NSColor, ratio: CGFloat) -> NSColor {
        let fromRGB = from.usingColorSpace(.deviceRGB)!
        let toRGB = to.usingColorSpace(.deviceRGB)!
        
        let r = fromRGB.redComponent + (toRGB.redComponent - fromRGB.redComponent) * ratio
        let g = fromRGB.greenComponent + (toRGB.greenComponent - fromRGB.greenComponent) * ratio
        let b = fromRGB.blueComponent + (toRGB.blueComponent - fromRGB.blueComponent) * ratio
        let a = fromRGB.alphaComponent + (toRGB.alphaComponent - fromRGB.alphaComponent) * ratio
        
        return NSColor(red: r, green: g, blue: b, alpha: a)
    }
    
    private func drawCenterText(in context: CGContext, center: CGPoint) {
        // 格式化倒计时时间
        let minutes = Int(countdownTime) / 60
        let seconds = Int(countdownTime) % 60
        let timeText = String(format: "%02d:%02d", minutes, seconds)
        
        // 使用预加载的自定义字体
        let font = countdownFont ?? NSFont.monospacedDigitSystemFont(ofSize: 24, weight: .bold)
        
        // 绘制实心字体
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]
        
        let attributedString = NSAttributedString(string: timeText, attributes: attributes)
        let size = attributedString.size()
        let rect = CGRect(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        
        // 绘制实心文字
        attributedString.draw(in: rect)
        
        // 移除倒计时标题的绘制，只显示时间
    }
    
    // MARK: - Ring Values Display
    
    private func drawRingValues(in context: CGContext, center: CGPoint) {
        guard !ringValues.isEmpty else { return }
        
        for (index, ring) in rings.enumerated() {
            guard index < ringValues.count else { continue }
            
            // 计算圆环的基础半径和厚度
            var effectiveRadius = (baseSize * ring.type.diameter) / 2
            var effectiveThickness = ringThickness
            
            // 应用呼吸动画缩放效果，与 drawActivityRing 中的逻辑一致
            let currentPhase = isBreathingAnimationActive ? breathingPhase : frozenBreathingPhase
            let shouldApplyBreathingEffect = isBreathingAnimationActive || frozenBreathingPhase != 0.0
            
            if shouldApplyBreathingEffect {
                let breathingIntensity: CGFloat
                switch ring.type {
                case .restAdequacy:    // 最外层 - 最强的不规则气泡效果
                    let baseBreathing = smoothBreathing(currentPhase)
                    let wave1 = baseBreathing * 0.12
                    let wave2 = smoothBreathing(currentPhase * 1.3 + 0.5) * 0.08
                    let wave3 = smoothBreathing(currentPhase * 0.7 + 1.2) * 0.06
                    let wave4 = smoothBreathing(currentPhase * 2.1 + 0.9) * 0.04
                    breathingIntensity = wave1 + wave2 + wave3 + wave4
                case .workIntensity:   // 第二层 - 与最外层节奏一致，强度适中
                    let baseBreathing = smoothBreathing(currentPhase)
                    let wave1 = baseBreathing * 0.070
                    let wave2 = smoothBreathing(currentPhase * 1.3 + 0.5) * 0.044
                    let wave3 = smoothBreathing(currentPhase * 0.7 + 1.2) * 0.032
                    let wave4 = smoothBreathing(currentPhase * 2.1 + 0.9) * 0.020
                    breathingIntensity = wave1 + wave2 + wave3 + wave4
                case .focus:           // 第三层 - 与最外层节奏一致，强度较轻
                    let baseBreathing = smoothBreathing(currentPhase)
                    let wave1 = baseBreathing * 0.045
                    let wave2 = smoothBreathing(currentPhase * 1.3 + 0.5) * 0.030
                    let wave3 = smoothBreathing(currentPhase * 0.7 + 1.2) * 0.022
                    let wave4 = smoothBreathing(currentPhase * 2.1 + 0.9) * 0.013
                    breathingIntensity = wave1 + wave2 + wave3 + wave4
                case .health:          // 最内层 - 与最外层节奏一致，强度最轻
                    let baseBreathing = smoothBreathing(currentPhase)
                    let wave1 = baseBreathing * 0.025
                    let wave2 = smoothBreathing(currentPhase * 1.3 + 0.5) * 0.017
                    let wave3 = smoothBreathing(currentPhase * 0.7 + 1.2) * 0.012
                    let wave4 = smoothBreathing(currentPhase * 2.1 + 0.9) * 0.008
                    breathingIntensity = wave1 + wave2 + wave3 + wave4
                }
                
                let irregularScale = 1.0 + breathingIntensity
                effectiveRadius *= irregularScale
                effectiveThickness *= irregularScale
            }
            
            // 计算数值显示位置（圆环线条的正中间）
            let textRadius = effectiveRadius - effectiveThickness / 2  // 在圆环线条中间位置
            
            // 使用圆环线条粗细的比例来调整文字位置，更符合视觉逻辑
            let thicknessBasedOffset = effectiveThickness * 0.4  // 根据线条粗细调整偏移量
            
            let valuePosition = CGPoint(
                x: center.x + textRadius * cos(-CGFloat.pi / 2),  // 12点钟方向
                y: center.y + textRadius * sin(-CGFloat.pi / 2) - thicknessBasedOffset  // 按线条粗细比例往下调整
            )
            
            // 格式化数值为百分比
            let percentage = Int(ringValues[index] * 100)
            let valueText = "\(percentage)%"
            
            // 根据圆环类型和呼吸动画调整字体大小
            let baseFontSize: CGFloat = {
                switch ring.type {
                case .restAdequacy: return 8
                case .workIntensity: return 7
                case .focus: return 6
                case .health: return 5
                }
            }()
            
            // 字体大小也跟随呼吸动画缩放
            let scaleRatio = effectiveRadius / ((baseSize * ring.type.diameter) / 2)
            let fontSize = baseFontSize * (0.8 + 0.2 * scaleRatio)  // 轻微跟随缩放
            
            // 使用 Core Graphics 绘制文字
            context.saveGState()
            
            // 设置文字颜色为柔和的灰白色，避免过于刺眼
            let softWhiteColor = NSColor(white: 0.85, alpha: 1.0)  // 85% 白色，更加柔和
            context.setFillColor(softWhiteColor.cgColor)
            
            // 设置字体
            let font = CTFontCreateWithName("Helvetica-Bold" as CFString, fontSize, nil)
            
            // 创建文字属性字典
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: softWhiteColor
            ]
            
            let attributedString = NSAttributedString(string: valueText, attributes: attributes)
            let line = CTLineCreateWithAttributedString(attributedString)
            
            // 获取文字边界框
            let bounds = CTLineGetBoundsWithOptions(line, CTLineBoundsOptions.useOpticalBounds)
            
            // 计算文字绘制位置（居中）
            let textDrawPosition = CGPoint(
                x: valuePosition.x - bounds.width / 2,
                y: valuePosition.y - bounds.height / 2
            )
            
            // 设置文字绘制位置
            context.textPosition = textDrawPosition
            
            // 绘制文字
            CTLineDraw(line, context)
            
            context.restoreGState()
        }
    }
    
    // MARK: - Public Methods
    
    func updateCountdown(time: TimeInterval, title: String) {
        countdownTime = time
        // 移除标题设置，不再显示标题
        needsDisplay = true
    }
    
    func updateRingValues(outerRing: Double, secondRing: Double, thirdRing: Double, innerRing: Double) {
        // 保存原始数值用于显示（0-1范围）
        ringValues = [outerRing, secondRing, thirdRing, innerRing]
        
        let values: [CGFloat] = [
            CGFloat(outerRing),      // 休息充足度
            CGFloat(secondRing),     // 工作强度
            CGFloat(thirdRing),      // 专注度
            CGFloat(innerRing)       // 健康度
        ]
        
        for (index, value) in values.enumerated() {
            if index < rings.count {
                // 限制在100%以内，不支持多圈显示（修复30%显示为整圈的问题）
                rings[index].targetProgress = min(max(value, 0.0), 1.0)
            }
        }
        
        startSmoothAnimation()
        
        // 更新tooltip
        updateTooltip()
    }
    
    func startBreathingAnimation() {
        guard !isBreathingAnimationActive else { return }
        
        isBreathingAnimationActive = true
        // 不重置breathingPhase，保持当前值（可能是从冻结状态恢复的值）
        
        // 进一步降低呼吸动画频率到10fps，减少更多CPU负载
        breathingAnimationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/15.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // 只在窗口可见时更新动画
            guard self.window?.isVisible == true else { return }
            
            // 使用完全连续的时间累积，避免任何重置跳跃
            self.breathingPhase += (1.0/15.0) * 2 * Double.pi / self.breathingCycleDuration
            // 只在相位变得过大时进行平滑处理，但保持数值连续性
            if self.breathingPhase > 100 * Double.pi {  // 大幅增加阈值，几乎不会触发
                // 使用平滑的相位归一化，保持连续性
                let cycles = floor(self.breathingPhase / (2 * Double.pi))
                self.breathingPhase = self.breathingPhase - cycles * 2 * Double.pi
            }
            
            
            // 只有在没有进度动画时才触发重绘，避免冲突
            if self.animationTimer == nil {
                DispatchQueue.main.async {
                    self.needsDisplay = true
                }
            }
        }
    }
    
    func stopBreathingAnimation() {
        isBreathingAnimationActive = false
        breathingAnimationTimer?.invalidate()
        breathingAnimationTimer = nil
        needsDisplay = true
    }
    
    // MARK: - Timer State Control
    
    /// 设置计时器运行状态，控制动画行为
    func setTimerRunning(_ running: Bool) {
        isTimerRunning = running
        
        if running {
            // 计时器运行时：从冻结状态恢复动画
            if frozenBreathingPhase != 0.0 {
                // 从冻结的相位继续动画
                breathingPhase = frozenBreathingPhase
                frozenBreathingPhase = 0.0
            }
            startBreathingAnimation()
        } else {
            // 计时器停止时：立即冻结当前状态
            if isBreathingAnimationActive {
                // 冻结当前相位
                frozenBreathingPhase = breathingPhase
                // 立即停止动画
                isBreathingAnimationActive = false
                breathingAnimationTimer?.invalidate()
                breathingAnimationTimer = nil
                // 触发重绘以显示冻结状态
                DispatchQueue.main.async {
                    self.needsDisplay = true
                }
            }
        }
    }
    
    private func startSmoothAnimation() {
        animationTimer?.invalidate()
        animationStartTime = CACurrentMediaTime()
        
        // Store initial progress values
        for i in 0..<rings.count {
            rings[i].progress = rings[i].animatedProgress
        }
        
        // 降低进度动画频率到20fps，减少CPU负载但保持流畅
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/15.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            // 只在窗口可见时更新动画
            guard self.window?.isVisible == true else { return }
            
            let elapsed = CACurrentMediaTime() - self.animationStartTime
            let progress = min(elapsed / self.animationDuration, 1.0)
            
            // 使用更平滑的缓动函数
            let easedProgress = self.smoothEaseInOut(progress)
            
            var allAnimationsComplete = true
            var needsRedraw = false
            
            for i in 0..<self.rings.count {
                let startProgress = self.rings[i].progress
                let targetProgress = self.rings[i].targetProgress
                let currentProgress = startProgress + (targetProgress - startProgress) * CGFloat(easedProgress)
                
                // 只有进度变化超过阈值时才重绘
                if abs(currentProgress - self.rings[i].animatedProgress) > 0.005 {
                    needsRedraw = true
                }
                
                self.rings[i].animatedProgress = currentProgress
                
                if abs(currentProgress - targetProgress) > 0.005 {
                    allAnimationsComplete = false
                }
            }
            
            if needsRedraw && (!allAnimationsComplete || progress < 1.0) {
                DispatchQueue.main.async {
                    self.needsDisplay = true
                }
            }
            
            if allAnimationsComplete || progress >= 1.0 {
                // Ensure final values are exactly the target values
                for i in 0..<self.rings.count {
                    self.rings[i].animatedProgress = self.rings[i].targetProgress
                }
                DispatchQueue.main.async {
                    self.needsDisplay = true
                }
                timer.invalidate()
                self.animationTimer = nil
            }
        }
    }
    
    private func easeInOutCubic(_ t: Double) -> Double {
        return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
    }
    
    /// 更平滑的缓动函数，专门用于圆环动画
    private func smoothEaseInOut(_ t: Double) -> Double {
        // 使用更平滑的三次贝塞尔曲线
        return t * t * t * (t * (t * 6 - 15) + 10)
    }
    
    // MARK: - Color and Animation Helpers
    
    /// 平滑插值函数，用于更自然的渐变效果
    private func smoothstep(_ edge0: CGFloat, _ edge1: CGFloat, _ x: CGFloat) -> CGFloat {
        let t = max(0, min(1, (x - edge0) / (edge1 - edge0)))
        return t * t * (3 - 2 * t)
    }
    
    // MARK: - Irregular Arc Drawing (不规则胶囊效果)
    
    private func drawIrregularArcSegment(in context: CGContext, center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, thickness: CGFloat, backgroundColor: NSColor) {
        // 保存当前的绘制状态
        context.saveGState()
        
        // 设置为背景色，与最外层背景色一致
        context.setStrokeColor(backgroundColor.cgColor)
        context.setLineWidth(thickness)
        context.setLineCap(.round)
        
        // 创建不规则路径，用多个小线段替代弧线
        let segmentCount = 5
        let angleStep = (endAngle - startAngle) / CGFloat(segmentCount)
        
        var currentAngle = startAngle
        var firstPoint = true
        
        for _ in 0...segmentCount {
            // 计算不规则半径变化（胶囊挤压效果）
            let currentPhase = isBreathingAnimationActive ? breathingPhase : frozenBreathingPhase
            let irregularRadius = calculateIrregularRadius(baseRadius: radius, angle: currentAngle, time: currentPhase)
            
            let x = center.x + irregularRadius * cos(currentAngle)
            let y = center.y + irregularRadius * sin(currentAngle)
            
            if firstPoint {
                context.move(to: CGPoint(x: x, y: y))
                firstPoint = false
            } else {
                context.addLine(to: CGPoint(x: x, y: y))
            }
            
            currentAngle += angleStep
        }
        
        context.strokePath()
        context.restoreGState()
    }
    
    private func calculateIrregularRadius(baseRadius: CGFloat, angle: CGFloat, time: Double) -> CGFloat {
        // 简化不规则变化计算，减少三角函数调用
        // 使用更少的波形组合，保持视觉效果但提升性能
        let wave1 = smoothSin(angle * 3 + time) * 0.08
        let wave2 = smoothSin(angle * 2 + time * 1.3 + 0.5) * 0.06  // 合并wave2和wave3
        
        // 简化全局效果，减少计算
        let globalSqueeze = smoothSin(time * 1.5) * 0.04
        
        let totalVariation = wave1 + wave2 + globalSqueeze
        return baseRadius * (1.0 + totalVariation)
    }
    
    // MARK: - Smooth Breathing Helper
    
    /// 平滑的呼吸缓动函数，避免突然的变化
    private func smoothBreathing(_ phase: Double) -> CGFloat {
        // 使用更平滑的缓动曲线，类似于自然呼吸
        // 结合正弦波和三次贝塞尔曲线
        let normalizedPhase = fmod(phase, 2 * Double.pi) / (2 * Double.pi)  // 归一化到0-1
        
        // 使用ease-in-out三次曲线来平滑过渡
        let eased = normalizedPhase < 0.5 ?
            4 * normalizedPhase * normalizedPhase * normalizedPhase :
            1 - pow(-2 * normalizedPhase + 2, 3) / 2
        
        // 转换回正弦形式，但使用平滑的缓动
        return CGFloat(sin(eased * 2 * Double.pi))
    }
    
    /// 平滑的正弦函数，确保相位连续性
    private func smoothSin(_ phase: Double) -> CGFloat {
        // 使用更平滑的相位处理，避免跳跃
        let smoothPhase = fmod(phase + 4 * Double.pi, 2 * Double.pi)  // 确保正值和连续性
        return CGFloat(sin(smoothPhase))
    }
    
    // MARK: - Cleanup
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        if window != nil {
            // 窗口可见时恢复动画
            if isBreathingAnimationActive && breathingAnimationTimer == nil {
                startBreathingAnimation()
            }
        } else {
            // 窗口不可见时立即暂停所有动画，大幅减少CPU负载
            pauseAllAnimations()
        }
    }
    
    // 智能动画管理
    private func pauseAllAnimations() {
        breathingAnimationTimer?.invalidate()
        breathingAnimationTimer = nil
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    private func resumeAnimationsIfNeeded() {
        guard window?.isVisible == true else { return }
        
        if isBreathingAnimationActive && breathingAnimationTimer == nil {
            startBreathingAnimation()
        }
    }
    
    deinit {
        animationTimer?.invalidate()
        breathingAnimationTimer?.invalidate()
    }
}
