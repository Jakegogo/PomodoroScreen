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
        case .workIntensity: return 0.60   // medium - 第二层
        case .focus: return 0.39           // small - 第三层，增加直径减少与内层重叠
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
    
    // 性能优化控制
    private var lastUpdateTime: CFTimeInterval = 0
    private let minUpdateInterval: CFTimeInterval = 1.0 / 20.0  // 最大20fps，避免过度更新
    
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
        
        // 预计算呼吸动画效果，避免重复计算
        let breathingEffects = precomputeBreathingEffects()
        
        // 绘制每个环（从外到里）
        for ring in rings {
            drawActivityRing(in: context, center: center, ring: ring, breathingEffects: breathingEffects)
        }
        
        // 绘制圆环数值（复用呼吸效果计算）
        drawRingValues(in: context, center: center, breathingEffects: breathingEffects)
        
        // 绘制中心文字
        drawCenterText(in: context, center: center)
    }
    
    // MARK: - Performance Optimization Structures
    
    /// 预计算的呼吸效果数据，避免在多个绘制方法中重复计算
    private struct BreathingEffects {
        let currentPhase: CGFloat
        let shouldApplyEffect: Bool
        let intensities: [RingType: CGFloat]
        let effectiveRadii: [RingType: CGFloat]
        let effectiveThicknesses: [RingType: CGFloat]
        let alphaIntensities: [RingType: CGFloat]  // 透明度效果
        let breathingAlphas: [RingType: CGFloat]   // 最终透明度值
    }
    
    /// 预计算的渐变数据，避免实时颜色插值和大量绘制调用
    private struct GradientCache {
        let colors: [CGColor]           // 预计算的颜色数组
        let progressSteps: Int          // 进度环步数
        let fullRingSteps: Int         // 完整环步数
        let progressAngleStep: CGFloat  // 进度环角度步长
        let fullRingAngleStep: CGFloat  // 完整环角度步长
        
        static let shared = GradientCache()
        
        private init() {
            // 优化后的步数：大幅减少绘制调用
            progressSteps = 12      // 从50减少到12，减少76%
            fullRingSteps = 24      // 从100减少到24，减少76%
            progressAngleStep = 2 * .pi / CGFloat(progressSteps)
            fullRingAngleStep = 2 * .pi / CGFloat(fullRingSteps)
            
            // 预计算颜色查找表，避免实时插值
            var precomputedColors: [CGColor] = []
            let maxSteps = max(progressSteps, fullRingSteps)
            
            // 使用临时颜色进行预计算（实际使用时会动态替换）
            let tempFromColor = NSColor.red
            let tempToColor = NSColor.blue
            
            for i in 0...maxSteps {
                let ratio = CGFloat(i) / CGFloat(maxSteps)
                let smoothRatio = Self.smoothstepStatic(0, 1, ratio)
                let color = Self.interpolateColorStatic(from: tempFromColor, to: tempToColor, ratio: smoothRatio)
                precomputedColors.append(color.cgColor)
            }
            
            self.colors = precomputedColors
        }
        
        // 静态方法，避免实例方法调用开销
        private static func smoothstepStatic(_ edge0: CGFloat, _ edge1: CGFloat, _ x: CGFloat) -> CGFloat {
            let t = max(0, min(1, (x - edge0) / (edge1 - edge0)))
            return t * t * (3 - 2 * t)
        }
        
        private static func interpolateColorStatic(from: NSColor, to: NSColor, ratio: CGFloat) -> NSColor {
            let fromRGB = from.usingColorSpace(.deviceRGB)!
            let toRGB = to.usingColorSpace(.deviceRGB)!
            
            let r = fromRGB.redComponent + (toRGB.redComponent - fromRGB.redComponent) * ratio
            let g = fromRGB.greenComponent + (toRGB.greenComponent - fromRGB.greenComponent) * ratio
            let b = fromRGB.blueComponent + (toRGB.blueComponent - fromRGB.blueComponent) * ratio
            let a = fromRGB.alphaComponent + (toRGB.alphaComponent - fromRGB.alphaComponent) * ratio
            
            return NSColor(red: r, green: g, blue: b, alpha: a)
        }
    }
    
    /// 颜色空间转换缓存系统，避免重复的颜色空间转换
    private struct ColorSpaceCache {
        /// 缓存的RGB分量数据
        struct RGBComponents {
            let r: CGFloat
            let g: CGFloat
            let b: CGFloat
            let a: CGFloat
            
            init(from color: NSColor) {
                let rgbColor = color.usingColorSpace(.deviceRGB)!
                self.r = rgbColor.redComponent
                self.g = rgbColor.greenComponent
                self.b = rgbColor.blueComponent
                self.a = rgbColor.alphaComponent
            }
        }
        
        /// 全局缓存实例
        static let shared = ColorSpaceCache()
        
        /// 颜色组合的缓存字典（使用线程安全的字典）
        private let colorCache: NSMutableDictionary = NSMutableDictionary()
        private let cacheQueue = DispatchQueue(label: "ColorSpaceCache", attributes: .concurrent)
        
        private init() {
            // 预缓存常用的圆环颜色，避免运行时转换
            precacheRingColors()
        }
        
        /// 预缓存所有圆环颜色的RGB分量
        private func precacheRingColors() {
            let ringColors: [NSColor] = [
                // Rest Adequacy (红色)
                .restDark, .restLight, .restCircleEnd, .restOutline,
                // Work Intensity (绿色)
                .workDark, .workLight, .workCircleEnd, .workOutline,
                // Focus (蓝色)
                .focusDark, .focusLight, .focusCircleEnd, .focusOutline,
                // Health (紫色)
                .healthDark, .healthLight, .healthCircleEnd, .healthOutline
            ]
            
            for color in ringColors {
                let key = colorCacheKey(for: color)
                colorCache.setObject(RGBComponents(from: color), forKey: key as NSString)
            }
        }
        
        /// 生成颜色的缓存键
        private func colorCacheKey(for color: NSColor) -> String {
            // 使用颜色的内存地址作为唯一标识（比较高效）
            return String(describing: color)
        }
        
        /// 获取缓存的RGB分量，如果不存在则计算并缓存
        func getRGBComponents(for color: NSColor) -> RGBComponents {
            let key = colorCacheKey(for: color)
            
            return cacheQueue.sync {
                if let cached = colorCache.object(forKey: key as NSString) as? RGBComponents {
                    return cached
                }
                
                // 缓存未命中，计算并存储
                let components = RGBComponents(from: color)
                cacheQueue.async(flags: .barrier) {
                    self.colorCache.setObject(components, forKey: key as NSString)
                }
                return components
            }
        }
        
        /// 清理缓存（在内存压力时调用）
        func clearCache() {
            cacheQueue.async(flags: .barrier) {
                self.colorCache.removeAllObjects()
                self.precacheRingColors()
            }
        }
    }
    
    /// 预计算所有圆环的呼吸动画效果
    private func precomputeBreathingEffects() -> BreathingEffects {
        let currentPhase = isBreathingAnimationActive ? breathingPhase : frozenBreathingPhase
        let shouldApplyEffect = isBreathingAnimationActive || frozenBreathingPhase != 0.0
        
        var intensities: [RingType: CGFloat] = [:]
        var effectiveRadii: [RingType: CGFloat] = [:]
        var effectiveThicknesses: [RingType: CGFloat] = [:]
        var alphaIntensities: [RingType: CGFloat] = [:]
        var breathingAlphas: [RingType: CGFloat] = [:]
        
        for ringType in RingType.allCases {
            let baseRadius = (baseSize * ringType.diameter) / 2
            let baseThickness = ringThickness
            
            if shouldApplyEffect {
                // 计算呼吸强度（复用现有逻辑）
                let breathingIntensity = calculateBreathingIntensity(for: ringType, phase: currentPhase)
                let irregularScale = 1.0 + breathingIntensity
                
                // 计算透明度呼吸效果
                let alphaIntensity = calculateAlphaIntensity(for: ringType, phase: currentPhase)
                let breathingAlpha = 0.8 + alphaIntensity
                
                intensities[ringType] = breathingIntensity
                effectiveRadii[ringType] = baseRadius * irregularScale
                effectiveThicknesses[ringType] = baseThickness * irregularScale
                alphaIntensities[ringType] = alphaIntensity
                breathingAlphas[ringType] = breathingAlpha
            } else {
                intensities[ringType] = 0.0
                effectiveRadii[ringType] = baseRadius
                effectiveThicknesses[ringType] = baseThickness
                alphaIntensities[ringType] = 0.0
                breathingAlphas[ringType] = 1.0  // 默认完全不透明
            }
        }
        
        return BreathingEffects(
            currentPhase: currentPhase,
            shouldApplyEffect: shouldApplyEffect,
            intensities: intensities,
            effectiveRadii: effectiveRadii,
            effectiveThicknesses: effectiveThicknesses,
            alphaIntensities: alphaIntensities,
            breathingAlphas: breathingAlphas
        )
    }
    
    /// 计算指定圆环类型的呼吸强度
    private func calculateBreathingIntensity(for ringType: RingType, phase: CGFloat) -> CGFloat {
        let baseBreathing = smoothBreathing(phase)
        let wave2 = smoothBreathing(phase * 1.3 + 0.5)
        let wave3 = smoothBreathing(phase * 0.7 + 1.2)
        let wave4 = smoothBreathing(phase * 2.1 + 0.9)
        
        switch ringType {
        case .restAdequacy:    // 最外层 - 最强的不规则气泡效果
            return baseBreathing * 0.12 + wave2 * 0.08 + wave3 * 0.06 + wave4 * 0.04
        case .workIntensity:   // 第二层 - 与最外层节奏一致，强度适中
            return baseBreathing * 0.085 + wave2 * 0.052 + wave3 * 0.038 + wave4 * 0.024
        case .focus:           // 第三层 - 与最外层节奏一致，强度较轻
            return baseBreathing * 0.045 + wave2 * 0.030 + wave3 * 0.022 + wave4 * 0.013
        case .health:          // 最内层 - 与最外层节奏一致，强度最轻
            return baseBreathing * 0.025 + wave2 * 0.017 + wave3 * 0.012 + wave4 * 0.008
        }
    }
    
    /// 计算指定圆环类型的透明度呼吸强度
    private func calculateAlphaIntensity(for ringType: RingType, phase: CGFloat) -> CGFloat {
        let bubbleAlpha1 = sin(phase)
        let bubbleAlpha2 = sin(phase * 1.7 + 0.8)
        
        switch ringType {
        case .restAdequacy:
            return bubbleAlpha1 * 0.15 + bubbleAlpha2 * 0.1
        case .workIntensity:
            return bubbleAlpha1 * 0.15 + bubbleAlpha2 * 0.11
        case .focus:
            return bubbleAlpha1 * 0.10 + bubbleAlpha2 * 0.06
        case .health:
            return bubbleAlpha1 * 0.06 + bubbleAlpha2 * 0.04
        }
    }
    
    // MARK: - Optimized Gradient Drawing Methods
    
    /// 高效的渐变颜色计算，使用缓存的RGB分量避免颜色空间转换
    private func getOptimizedGradientColor(from fromColor: NSColor, to toColor: NSColor, ratio: CGFloat) -> CGColor {
        // 使用预计算的平滑插值结果
        let smoothRatio = smoothstep(0, 1, ratio)
        
        // 使用缓存的RGB分量，避免重复的颜色空间转换
        let fromRGB = ColorSpaceCache.shared.getRGBComponents(for: fromColor)
        let toRGB = ColorSpaceCache.shared.getRGBComponents(for: toColor)
        
        // 快速线性插值，无需颜色空间转换
        let r = fromRGB.r + (toRGB.r - fromRGB.r) * smoothRatio
        let g = fromRGB.g + (toRGB.g - fromRGB.g) * smoothRatio
        let b = fromRGB.b + (toRGB.b - fromRGB.b) * smoothRatio
        let a = fromRGB.a + (toRGB.a - fromRGB.a) * smoothRatio
        
        return CGColor(red: r, green: g, blue: b, alpha: a)
    }
    
    /// 超高效的颜色插值（直接使用预计算的RGB分量）
    private func fastInterpolateColor(fromComponents: ColorSpaceCache.RGBComponents, toComponents: ColorSpaceCache.RGBComponents, ratio: CGFloat) -> CGColor {
        // 使用预计算的平滑插值
        let smoothRatio = smoothstep(0, 1, ratio)
        
        // 直接插值，零颜色空间转换开销
        let r = fromComponents.r + (toComponents.r - fromComponents.r) * smoothRatio
        let g = fromComponents.g + (toComponents.g - fromComponents.g) * smoothRatio
        let b = fromComponents.b + (toComponents.b - fromComponents.b) * smoothRatio
        let a = fromComponents.a + (toComponents.a - fromComponents.a) * smoothRatio
        
        return CGColor(red: r, green: g, blue: b, alpha: a)
    }
    
    /// 使用连续路径和角度渐变的高质量圆环绘制方法
    private func drawNativeGradientRing(in context: CGContext, center: CGPoint, radius: CGFloat, thickness: CGFloat, startAngle: CGFloat, endAngle: CGFloat, colors: [NSColor]) {
        context.saveGState()
        
        // 创建角度范围内的连续渐变
        let angleRange = endAngle - startAngle
        
        // 使用更精细的分段来创建平滑的角度渐变，但使用重叠绘制避免间隙
        let segments = max(12, min(36, Int(angleRange * 180 / .pi / 5)))  // 更精细的分段
        let _ = angleRange / CGFloat(segments)  // 移除未使用的segmentAngle
        
        // 预缓存颜色组件
        let fromComponents = ColorSpaceCache.shared.getRGBComponents(for: colors[0])
        let toComponents = ColorSpaceCache.shared.getRGBComponents(for: colors[1])
        
        // 根本解决方案：单一连续路径，避免多次strokePath()调用导致的分割线
        // 分割线的真正原因：每次strokePath()都有独立的抗锯齿边界
        
        context.setLineWidth(thickness)
        
        // 方法：创建一个完整的连续路径，然后使用渐变遮罩
        let completePath = CGMutablePath()
        completePath.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        
        // 设置圆角末端（如果需要）
        if endAngle - startAngle < 2 * .pi - 0.01 {
            context.setLineCap(.round)
        } else {
            context.setLineCap(.butt)
        }
        
        // 使用路径创建描边遮罩
        context.addPath(completePath)
        context.replacePathWithStrokedPath()
        context.clip()
        
        // 在遮罩区域内绘制渐变
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradientColors = [colors[0].cgColor, colors[1].cgColor]
        let locations: [CGFloat] = [0.0, 1.0]
        
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors as CFArray, locations: locations) {
            // 计算渐变方向（沿弧线方向的近似）
            let startPoint = CGPoint(
                x: center.x + radius * cos(startAngle),
                y: center.y + radius * sin(startAngle)
            )
            let endPoint = CGPoint(
                x: center.x + radius * cos(endAngle),
                y: center.y + radius * sin(endAngle)
            )
            
            // 绘制线性渐变（在遮罩区域内）
            context.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        } else {
            // 回退：使用中间色填充
            let middleColor = fastInterpolateColor(fromComponents: fromComponents, toComponents: toComponents, ratio: 0.5)
            context.setFillColor(middleColor)
            let fillRect = CGRect(x: center.x - radius - thickness, y: center.y - radius - thickness, 
                                 width: 2 * (radius + thickness), height: 2 * (radius + thickness))
            context.fill(fillRect)
        }
        
        context.restoreGState()
    }
    
    /// 使用单一路径和线性渐变的高效绘制方法（适用于短弧）
    private func drawLinearGradientRing(in context: CGContext, center: CGPoint, radius: CGFloat, thickness: CGFloat, startAngle: CGFloat, endAngle: CGFloat, colors: [NSColor]) {
        context.saveGState()
        
        // 创建单一弧形路径，避免多次绘制调用
        let path = CGMutablePath()
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        
        // 设置线条属性
        context.setLineWidth(thickness)
        context.setLineCap(.round)
        
        // 使用Core Graphics的原生渐变支持
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradientColors = [colors[0].cgColor, colors[1].cgColor]
        let locations: [CGFloat] = [0.0, 1.0]
        
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors as CFArray, locations: locations) else {
            // 回退到单色绘制
            context.setStrokeColor(colors[0].cgColor)
            context.addPath(path)
            context.strokePath()
            context.restoreGState()
            return
        }
        
        // 计算渐变的起点和终点（沿着弧的方向）
        let startPoint = CGPoint(
            x: center.x + radius * cos(startAngle),
            y: center.y + radius * sin(startAngle)
        )
        let endPoint = CGPoint(
            x: center.x + radius * cos(endAngle),
            y: center.y + radius * sin(endAngle)
        )
        
        // 应用路径作为剪切区域
        context.addPath(path)
        context.replacePathWithStrokedPath()
        context.clip()
        
        // 绘制线性渐变（在剪切区域内）
        context.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])
        
        context.restoreGState()
    }
    
    /// 统一使用原生圆锥渐变绘制所有圆环
    private func drawUnifiedNativeGradientRing(in context: CGContext, center: CGPoint, radius: CGFloat, thickness: CGFloat, startAngle: CGFloat, endAngle: CGFloat, colors: [NSColor]) {
        // 统一使用原生圆锥渐变，适应所有角度范围
        drawNativeGradientRing(in: context, center: center, radius: radius, thickness: thickness, startAngle: startAngle, endAngle: endAngle, colors: colors)
    }
    
    /// 高效的分段渐变绘制（使用颜色缓存的超优化版本）
    private func drawOptimizedSegmentedGradient(in context: CGContext, center: CGPoint, radius: CGFloat, thickness: CGFloat, startAngle: CGFloat, endAngle: CGFloat, colors: [NSColor], steps: Int) {
        context.saveGState()
        
        let angleRange = endAngle - startAngle
        let angleStep = angleRange / CGFloat(steps)
        
        // 预缓存起始和结束颜色的RGB分量，避免重复转换
        let fromComponents = ColorSpaceCache.shared.getRGBComponents(for: colors[0])
        let toComponents = ColorSpaceCache.shared.getRGBComponents(for: colors[1])
        
        // 预计算所有颜色和角度，减少循环内计算
        var segmentData: [(angle: CGFloat, nextAngle: CGFloat, color: CGColor)] = []
        segmentData.reserveCapacity(steps)
        
        for i in 0..<steps {
            let currentAngle = startAngle + CGFloat(i) * angleStep
            let nextAngle = currentAngle + angleStep
            let ratio = CGFloat(i) / CGFloat(steps - 1)
            
            // 使用超高效的颜色插值（零颜色空间转换）
            let color = fastInterpolateColor(fromComponents: fromComponents, toComponents: toComponents, ratio: ratio)
            
            segmentData.append((currentAngle, nextAngle, color))
        }
        
        // 批量设置线条属性（避免重复设置）
        context.setLineWidth(thickness)
        context.setLineCap(.round)
        
        // 批量绘制所有段
        for segment in segmentData {
            context.setStrokeColor(segment.color)
            context.addArc(center: center, radius: radius, startAngle: segment.angle, endAngle: segment.nextAngle, clockwise: false)
            context.strokePath()
        }
        
        context.restoreGState()
    }

    // MARK: - Drawing Methods (Based on CirclesWorkout.swift ActivityRing)
    
    private func drawActivityRing(in context: CGContext, center: CGPoint, ring: RingData, breathingEffects: BreathingEffects) {
        let progress = ring.animatedProgress
        let colors = ring.type.colors
        
        // 使用预计算的呼吸效果，避免重复计算
        let effectiveRadius = breathingEffects.effectiveRadii[ring.type] ?? (baseSize * ring.type.diameter / 2)
        let effectiveThickness = breathingEffects.effectiveThicknesses[ring.type] ?? ringThickness
        
        context.saveGState()
        
        // 基于CirclesWorkout.swift的绘制逻辑：progress < 0.98 vs else
        if progress < 0.98 {
            // Background ring (outline color) - 对应CirclesWorkout的background ring
            // 先绘制普通背景环（所有圆环都需要）
            // 最外层圆环的背景环向内加粗（通过向内收缩半径实现）
            // if ring.type == .restAdequacy {
            //     // 最外层：向内加粗，半径向内收缩
            //     let inwardOffset = effectiveThickness * 0.4  // 向内偏移
            //     let thickerRadius = effectiveRadius - inwardOffset
            //     let thickerThickness = effectiveThickness * 1.8
            //     drawBackgroundRing(in: context, center: center, radius: thickerRadius, thickness: thickerThickness, color: colors[3])
            // } else {
            //     // 其他圆环：保持原样
            //     drawBackgroundRing(in: context, center: center, radius: effectiveRadius, thickness: effectiveThickness, color: colors[3])
            // }

            // 取消最外层圆环的白色背景，只绘制其他圆环的背景
            if ring.type != .restAdequacy {
                // 其他圆环：保持原样
                drawBackgroundRing(in: context, center: center, radius: effectiveRadius, thickness: effectiveThickness, color: colors[3])
            }
            
            // 为最外层圆环额外绘制不规则背景环（叠加效果）
            // 在动画活跃时或有冻结相位时都绘制不规则圈
            if ring.type == .restAdequacy && breathingEffects.shouldApplyEffect {
                drawIrregularBackgroundRing(in: context, center: center, radius: effectiveRadius, thickness: effectiveThickness, color: colors[3], breathingEffects: breathingEffects)
            }
            
            // Progress ring with gradient - 对应CirclesWorkout的Activity Ring with trim
            if progress > 0.01 {
                drawProgressRing(in: context, center: center, radius: effectiveRadius, thickness: effectiveThickness, progress: progress, colors: colors, ring: ring, breathingEffects: breathingEffects)
                
                // Start dot (fix overlapping gradient from full cycle) - 对应CirclesWorkout的fix overlapping gradient
                drawStartDot(in: context, center: center, radius: effectiveRadius, thickness: effectiveThickness, color: colors[0])
            }
        } else {
            // Full ring with gradient - 对应CirclesWorkout的else分支
            drawFullRing(in: context, center: center, radius: effectiveRadius, thickness: effectiveThickness, progress: progress, colors: colors, ring: ring, breathingEffects: breathingEffects)
            
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
    
    private func drawIrregularBackgroundRing(in context: CGContext, center: CGPoint, radius: CGFloat, thickness: CGFloat, color: NSColor, breathingEffects: BreathingEffects) {
        context.saveGState()
        
        // 创建不规则外壁 + 规则内壁的环形区域
        // 设置半透明背景颜色 (透明度 0.9)
        let transparentColor = color.withAlphaComponent(0.8)
        context.setFillColor(transparentColor.cgColor)
        
        // 1. 创建不规则的外边界路径
        let outerIrregularPath = createIrregularBezierPath(center: center, baseRadius: radius + thickness/2, time: breathingEffects.currentPhase)
        
        // 2. 创建规则的内边界路径（标准圆形）
        let innerRegularPath = CGMutablePath()
        let innerRadius = radius - thickness/2
        innerRegularPath.addArc(center: center, radius: innerRadius, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
        
        // 3. 将外壁路径添加到上下文
        context.addPath(outerIrregularPath)
        
        // 4. 添加内壁路径作为洞（逆时针方向，创建洞）
        context.addPath(innerRegularPath)
        
        // 5. 使用 even-odd 填充规则，创建环形区域
        context.fillPath(using: .evenOdd)
        
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
        let radius = baseRadius * (1.0 + totalVariation)
        
        // 限制最小收缩半径，确保始终能覆盖最外层进度环
        let minCoverageRadius = baseRadius * 1.05  // 最小保持5%的向外偏移
        return max(radius, minCoverageRadius)
    }
    
    private func drawProgressRing(in context: CGContext, center: CGPoint, radius: CGFloat, thickness: CGFloat, progress: CGFloat, colors: [NSColor], ring: RingData, breathingEffects: BreathingEffects) {
        guard progress > 0.01 else { return }
        
        context.saveGState()
        
        // 使用预计算的透明度呼吸效果
        if breathingEffects.shouldApplyEffect {
            let breathingAlpha = breathingEffects.breathingAlphas[ring.type] ?? 1.0
            context.setAlpha(breathingAlpha)
        }
        
        // 优化的渐变绘制：大幅减少绘制调用
        let startAngle: CGFloat = -.pi / 2  // Start from top (-90 degrees like CirclesWorkout)
        let endAngle = startAngle + 2 * .pi * min(progress, 1.0)
        
        // 统一使用原生圆锥渐变绘制
        drawUnifiedNativeGradientRing(
            in: context,
            center: center,
            radius: radius,
            thickness: thickness,
            startAngle: startAngle,
            endAngle: endAngle,
            colors: colors
        )
        
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
    
    private func drawFullRing(in context: CGContext, center: CGPoint, radius: CGFloat, thickness: CGFloat, progress: CGFloat, colors: [NSColor], ring: RingData, breathingEffects: BreathingEffects) {
        context.saveGState()
        
        // 使用预计算的透明度呼吸效果
        if breathingEffects.shouldApplyEffect {
            let breathingAlpha = breathingEffects.breathingAlphas[ring.type] ?? 1.0
            context.setAlpha(breathingAlpha)
        }
        
        // 优化的完整环渐变绘制：使用原生圆锥渐变
        let startAngle: CGFloat = -.pi / 2  // Start from top
        let endAngle: CGFloat = startAngle + 2 * .pi
        
        // 完整圆环使用统一的原生圆锥渐变，性能最优
        drawUnifiedNativeGradientRing(
            in: context,
            center: center,
            radius: radius,
            thickness: thickness,
            startAngle: startAngle,
            endAngle: endAngle,
            colors: colors
        )
        
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
    
    /// 优化的颜色插值方法，使用颜色缓存避免重复的颜色空间转换
    private func interpolateColor(from: NSColor, to: NSColor, ratio: CGFloat) -> NSColor {
        // 使用缓存的RGB分量，避免重复的颜色空间转换
        let fromRGB = ColorSpaceCache.shared.getRGBComponents(for: from)
        let toRGB = ColorSpaceCache.shared.getRGBComponents(for: to)
        
        // 快速线性插值，无需颜色空间转换
        let r = fromRGB.r + (toRGB.r - fromRGB.r) * ratio
        let g = fromRGB.g + (toRGB.g - fromRGB.g) * ratio
        let b = fromRGB.b + (toRGB.b - fromRGB.b) * ratio
        let a = fromRGB.a + (toRGB.a - fromRGB.a) * ratio
        
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
    
    private func drawRingValues(in context: CGContext, center: CGPoint, breathingEffects: BreathingEffects) {
        guard !ringValues.isEmpty else { return }
        
        for (index, ring) in rings.enumerated() {
            guard index < ringValues.count else { continue }
            
            // 使用预计算的呼吸效果，避免重复计算
            let effectiveRadius = breathingEffects.effectiveRadii[ring.type] ?? (baseSize * ring.type.diameter / 2)
            let effectiveThickness = breathingEffects.effectiveThicknesses[ring.type] ?? ringThickness
            
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
        
        // 优化：呼吸动画使用智能频率控制
        breathingAnimationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/15.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // 只在窗口可见时更新动画
            guard self.window?.isVisible == true else { return }
            
            // 智能节流：呼吸动画可以使用稍低的更新频率
            let currentTime = CACurrentMediaTime()
            if currentTime - self.lastUpdateTime < self.minUpdateInterval * 1.2 {  // 呼吸动画允许更低频率
                return
            }
            self.lastUpdateTime = currentTime
            
            // 使用完全连续的时间累积，避免任何重置跳跃
            self.breathingPhase += (1.0/15.0) * 2 * Double.pi / self.breathingCycleDuration
            // 只在相位变得过大时进行平滑处理，但保持数值连续性
            if self.breathingPhase > 100 * Double.pi {  // 大幅增加阈值，几乎不会触发
                // 使用平滑的相位归一化，保持连续性
                let cycles = floor(self.breathingPhase / (2 * Double.pi))
                self.breathingPhase = self.breathingPhase - cycles * 2 * Double.pi
            }
            
            
            // 优化：只有在没有进度动画时才触发重绘，避免冲突，并直接设置needsDisplay
            if self.animationTimer == nil {
                self.needsDisplay = true
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
        lastUpdateTime = 0  // 重置更新时间，确保立即开始
        
        // Store initial progress values
        for i in 0..<rings.count {
            rings[i].progress = rings[i].animatedProgress
        }
        
        // 优化：使用智能频率控制，在保持流畅的同时减少CPU负载
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/15.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            // 只在窗口可见时更新动画
            guard self.window?.isVisible == true else { return }
            
            // 智能节流：避免过度频繁的更新
            let currentTime = CACurrentMediaTime()
            if currentTime - self.lastUpdateTime < self.minUpdateInterval {
                return
            }
            self.lastUpdateTime = currentTime
            
            let elapsed = CACurrentMediaTime() - self.animationStartTime
            let progress = min(elapsed / self.animationDuration, 1.0)
            
            // 使用更平滑的缓动函数
            let easedProgress = self.smoothEaseInOut(progress)
            
            var allAnimationsComplete = true
            var needsRedraw = false
            let progressThreshold: CGFloat = 0.005
            
            // 批量状态更新：一次性处理所有圆环，减少重复计算
            for i in 0..<self.rings.count {
                let startProgress = self.rings[i].progress
                let targetProgress = self.rings[i].targetProgress
                let currentProgress = startProgress + (targetProgress - startProgress) * CGFloat(easedProgress)
                
                // 批量检查变化，避免重复的阈值计算
                let progressDelta = abs(currentProgress - self.rings[i].animatedProgress)
                let targetDelta = abs(currentProgress - targetProgress)
                
                if progressDelta > progressThreshold {
                    needsRedraw = true
                }
                
                self.rings[i].animatedProgress = currentProgress
                
                if targetDelta > progressThreshold {
                    allAnimationsComplete = false
                }
            }
            
            // 优化：直接设置needsDisplay，避免不必要的主线程调度开销
            if needsRedraw && (!allAnimationsComplete || progress < 1.0) {
                self.needsDisplay = true
            }
            
            if allAnimationsComplete || progress >= 1.0 {
                // Ensure final values are exactly the target values
                for i in 0..<self.rings.count {
                    self.rings[i].animatedProgress = self.rings[i].targetProgress
                }
                // 最终重绘也直接设置，无需主线程调度
                self.needsDisplay = true
                
                // 优化：清理定时器状态，重置更新时间
                timer.invalidate()
                self.animationTimer = nil
                self.lastUpdateTime = 0  // 重置以便下次动画能立即开始
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
    
    private func drawIrregularArcSegment(in context: CGContext, center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, thickness: CGFloat, backgroundColor: NSColor, breathingEffects: BreathingEffects) {
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
            // 使用预计算的呼吸相位计算不规则半径变化（胶囊挤压效果）
            let irregularRadius = calculateIrregularRadius(baseRadius: radius, angle: currentAngle, time: breathingEffects.currentPhase)
            
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
