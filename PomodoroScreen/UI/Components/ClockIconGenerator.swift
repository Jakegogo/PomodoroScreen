//
//  ClockIconGenerator.swift
//  PomodoroScreen
//
//  Created by Assistant on 2025-09-22.
//

import Cocoa
import CoreText

class ClockIconGenerator {
    
    // MARK: - Properties
    
    private let iconSize: CGSize = CGSize(width: 20, height: 20)
    private let clockRadius: CGFloat = 8
    private let handWidth: CGFloat = 1.5
    
    // 缓存相关属性
    private var cachedIcon: NSImage?
    private var lastUpdateTime: Date = Date.distantPast
    private var lastProgress: Double = -1.0
    private var lastPaused: Bool = false
    private var lastRest: Bool = false
    private var lastRestMinutes: Int = -1
    private let cacheUpdateInterval: TimeInterval = 5.0 // 5秒更新间隔
    
    // MARK: - Public Methods
    
    /// 生成时钟样式的状态栏图标（带缓存机制）
    /// - Parameters:
    ///   - progress: 倒计时进度 (0.0 - 1.0)，0表示开始，1表示结束
    ///   - totalTime: 总时间（秒）
    ///   - remainingTime: 剩余时间（秒）
    ///   - isPaused: 是否为暂停态
    ///   - isRest: 是否处于休息期（优先于暂停态）
    /// - Returns: NSImage对象
    func generateClockIcon(progress: Double, totalTime: TimeInterval, remainingTime: TimeInterval, isPaused: Bool = false, isRest: Bool = false) -> NSImage {
        let currentTime = Date()
        let timeSinceLastUpdate = currentTime.timeIntervalSince(lastUpdateTime)
        
        // 检查是否需要更新缓存
        let currentRestMinutes = Int(ceil(remainingTime / 60.0))
        let shouldUpdateCache = cachedIcon == nil || 
                               timeSinceLastUpdate >= cacheUpdateInterval ||
                               abs(progress - lastProgress) > 0.01 || // 进度变化超过1%时也更新
                               isPaused != lastPaused || // 暂停状态切换时强制更新
                               isRest != lastRest || // 休息状态切换时强制更新
                               (isRest && currentRestMinutes != lastRestMinutes) // 休息分钟变化时更新
        
        if shouldUpdateCache {
            // 生成新的图标
            if isRest {
                cachedIcon = createRestIcon(progress: progress, remainingTime: remainingTime, totalTime: totalTime)
            } else if isPaused {
                cachedIcon = createPausedIcon(progress: progress)
            } else {
                cachedIcon = createClockIcon(progress: progress)
            }
            lastUpdateTime = currentTime
            lastProgress = progress
            lastPaused = isPaused
            lastRest = isRest
            lastRestMinutes = isRest ? currentRestMinutes : -1
        }
        
        if let icon = cachedIcon { return icon }
        if isRest { return createRestIcon(progress: progress, remainingTime: remainingTime, totalTime: totalTime) }
        return isPaused ? createPausedIcon(progress: progress) : createClockIcon(progress: progress)
    }
    
    /// 生成大尺寸的时钟图标（用于引导界面等需要清晰显示的场景）
    /// - Parameters:
    ///   - progress: 倒计时进度 (0.0 - 1.0)，0表示开始，1表示结束
    ///   - size: 图标尺寸
    /// - Returns: NSImage对象
    func generateLargeClockIcon(progress: Double, size: CGSize = CGSize(width: 80, height: 80)) -> NSImage {
        return createLargeClockIcon(progress: progress, size: size)
    }
    
    /// 清除图标缓存（在计时器重置或状态变化时调用）
    func clearCache() {
        cachedIcon = nil
        lastUpdateTime = Date.distantPast
        lastProgress = -1.0
        
        #if DEBUG
        print("🕐 Clock icon cache cleared")
        #endif
    }
    
    /// 强制更新图标缓存
    /// - Parameter progress: 当前进度
    /// - Returns: 更新后的图标
    func forceUpdateIcon(progress: Double) -> NSImage {
        cachedIcon = createClockIcon(progress: progress)
        lastUpdateTime = Date()
        lastProgress = progress
        
        #if DEBUG
        print("🕐 Clock icon force updated - Progress: \(String(format: "%.1f", progress * 100))%")
        #endif
        
        return cachedIcon!
    }
    
    /// 实际创建时钟图标的方法（原始版本，保持不变）
    /// - Parameter progress: 倒计时进度
    /// - Returns: NSImage对象
    private func createClockIcon(progress: Double) -> NSImage {
        let image = NSImage(size: iconSize)
        
        image.lockFocus()
        
        // 获取绘制上下文
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }
        
        // 设置坐标系（翻转Y轴以匹配时钟方向）
        context.translateBy(x: 0, y: iconSize.height)
        context.scaleBy(x: 1, y: -1)
        
        let center = CGPoint(x: iconSize.width / 2, y: iconSize.height / 2)
        
        // 绘制时钟背景圆圈
        drawClockBackground(in: context, center: center)
        
        // 绘制进度弧
        drawProgressArc(in: context, center: center, progress: progress)
        
        // 绘制时钟指针
        drawClockHand(in: context, center: center, progress: progress)
        
        // 绘制中心点
        drawCenterDot(in: context, center: center)
        
        image.unlockFocus()
        
        // 设置图像为模板图像，以便系统自动处理暗色模式
        image.isTemplate = true
        
        return image
    }

    /// 创建暂停状态图标：在背景圆圈中绘制进度弧与“暂停”竖条
    private func createPausedIcon(progress: Double) -> NSImage {
        let image = NSImage(size: iconSize)
        
        image.lockFocus()
        
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }
        
        // 坐标系
        context.translateBy(x: 0, y: iconSize.height)
        context.scaleBy(x: 1, y: -1)
        
        let center = CGPoint(x: iconSize.width / 2, y: iconSize.height / 2)
        
        // 背景圆圈
        drawClockBackground(in: context, center: center)
        
        // 进度弧（与运行中样式一致）
        drawProgressArc(in: context, center: center, progress: progress)
        
        // 绘制暂停竖条
        context.saveGState()
        context.setFillColor(NSColor.labelColor.cgColor)
        
        let barHeight = clockRadius * 0.9
        let barWidth: CGFloat = 1.6
        let barSpacing: CGFloat = 2.0
        
        let leftBarX = center.x - barSpacing/2 - barWidth
        let rightBarX = center.x + barSpacing/2
        let barY = center.y - barHeight/2
        
        let leftRect = CGRect(x: leftBarX, y: barY, width: barWidth, height: barHeight)
        let rightRect = CGRect(x: rightBarX, y: barY, width: barWidth, height: barHeight)
        
        context.fill(leftRect)
        context.fill(rightRect)
        context.restoreGState()
        
        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    /// 创建休息状态图标：进度弧 + 热水杯（休息符号）
    private func createRestIcon(progress: Double, remainingTime: TimeInterval, totalTime: TimeInterval) -> NSImage {
        let image = NSImage(size: iconSize)
        image.lockFocus()
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }
        // 坐标系
        context.translateBy(x: 0, y: iconSize.height)
        context.scaleBy(x: 1, y: -1)
        let center = CGPoint(x: iconSize.width / 2, y: iconSize.height / 2)
        
        // 绘制热水杯主体（简化版）
        context.saveGState()
        // 由于上方已整体进行了Y轴翻转，这里针对杯子再做一次以中心为基准的垂直翻转，
        // 使杯子在视觉上保持“正立”方向
        context.translateBy(x: center.x, y: center.y)
        context.scaleBy(x: 1, y: -1)
        context.translateBy(x: -center.x, y: -center.y)

        // 整体向下微调，避免图标偏上（单位：pt）
        let restYOffset: CGFloat = -0.8
        context.translateBy(x: 0, y: restYOffset)
        context.setFillColor(NSColor.labelColor.cgColor)
        context.setStrokeColor(NSColor.labelColor.cgColor)
        context.setLineWidth(1.2)

        // 杯体：位于画布下半部的圆角矩形
        let cupWidth = clockRadius * 1.4 // 进一步收窄杯体，确保含把手不超过20pt画布
        let cupHeight = clockRadius * 0.9
        let cupRect = CGRect(
            x: center.x - cupWidth / 2,
            y: center.y - cupHeight * 0.8,
            width: cupWidth,
            height: cupHeight
        )
        let cupPath = CGPath(roundedRect: cupRect, cornerWidth: 2, cornerHeight: 2, transform: nil)
        context.addPath(cupPath)
        context.fillPath()

        // 杯口：一条细线增强轮廓
        context.move(to: CGPoint(x: cupRect.minX + 0.5, y: cupRect.maxY))
        context.addLine(to: CGPoint(x: cupRect.maxX - 0.5, y: cupRect.maxY))
        context.strokePath()

        // 把手：杯体右侧一个小椭圆轮廓
        let handleRect = CGRect(
            x: cupRect.maxX - 0.6,
            y: cupRect.minY + cupHeight * 0.2,
            width: cupWidth * 0.38,
            height: cupHeight * 0.6
        )
        context.strokeEllipse(in: handleRect)

        // 蒸汽：三条波浪线（多段三次贝塞尔，弯折更丰富）
        context.setLineWidth(1.0)
        let steamBaseY = cupRect.maxY + 1.5

        func drawSteamWave(atX: CGFloat, height: CGFloat, amplitude: CGFloat, segments: Int) {
            let path = CGMutablePath()
            let step = height / CGFloat(segments)
            var y = steamBaseY
            path.move(to: CGPoint(x: atX, y: y))
            // 交替左右的控制点，形成波浪
            for i in 0..<segments {
                let dir: CGFloat = (i % 2 == 0) ? -1.0 : 1.0
                let y1 = y + step
                let c1 = CGPoint(x: atX + dir * amplitude, y: y + step * 0.33)
                let c2 = CGPoint(x: atX - dir * amplitude, y: y + step * 0.66)
                let p1 = CGPoint(x: atX, y: y1)
                path.addCurve(to: p1, control1: c1, control2: c2)
                y = y1
            }
            context.addPath(path)
            context.strokePath()
        }

        // 根据剩余分钟/总分钟比例，显示 1~3 条蒸汽，并保持整体水平居中
        let totalMinutes = max(1, Int(ceil(totalTime / 60.0)))
        let remainingMinutes = max(0, Int(ceil(remainingTime / 60.0)))
        let ratio = min(1.0, max(0.0, Double(remainingMinutes) / Double(totalMinutes)))
        let steamCount = max(1, min(3, Int(ceil(ratio * 3.0))))

        // 以杯体中心为基准的水平位移，保证蒸汽组居中
        let centerX = cupRect.midX
        let dx = cupWidth * 0.22

        switch steamCount {
        case 1:
            // 使用原中间蒸汽的参数
            drawSteamWave(atX: centerX, height: 6.2, amplitude: 1.1, segments: 3)
        case 2:
            // 左右各一，围绕中心对称，使用左右两侧原参数
            drawSteamWave(atX: centerX - dx * 0.5, height: 6.2, amplitude: 1.2, segments: 3)
            drawSteamWave(atX: centerX + dx * 0.5, height: 6.8, amplitude: 1.3, segments: 3)
        default:
            // 三条：左/中/右，保持与既有视觉接近
            drawSteamWave(atX: centerX - dx, height: 6.2, amplitude: 1.2, segments: 3)
            drawSteamWave(atX: centerX, height: 6.8, amplitude: 1.1, segments: 3)
            drawSteamWave(atX: centerX + dx, height: 7.0, amplitude: 1.3, segments: 3)
        }
        context.restoreGState()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }
    
    /// 创建大尺寸时钟图标的方法
    /// - Parameters:
    ///   - progress: 倒计时进度
    ///   - size: 图标尺寸
    /// - Returns: NSImage对象
    private func createLargeClockIcon(progress: Double, size: CGSize) -> NSImage {
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // 获取绘制上下文
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }
        
        // 设置坐标系（翻转Y轴以匹配时钟方向）
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        
        // 计算动态半径和线宽
        let radius = min(size.width, size.height) / 2 * 0.8
        let lineWidth = radius / 8
        
        // 绘制时钟背景圆圈
        drawLargeClockBackground(in: context, center: center, radius: radius, lineWidth: lineWidth)
        
        // 绘制进度弧
        drawLargeProgressArc(in: context, center: center, radius: radius, lineWidth: lineWidth, progress: progress)
        
        // 绘制时钟指针
        drawLargeClockHand(in: context, center: center, radius: radius, lineWidth: lineWidth, progress: progress)
        
        // 绘制中心点
        drawLargeCenterDot(in: context, center: center, radius: radius)
        
        image.unlockFocus()
        
        // 设置图像为模板图像，以便系统自动处理暗色模式
        image.isTemplate = true
        
        return image
    }
    
    // MARK: - Private Drawing Methods
    
    private func drawClockBackground(in context: CGContext, center: CGPoint) {
        context.saveGState()
        
        // 设置背景圆圈颜色和样式
        context.setStrokeColor(NSColor.controlAccentColor.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(1.0)
        
        // 绘制外圆
        let backgroundPath = CGPath(
            ellipseIn: CGRect(
                x: center.x - clockRadius,
                y: center.y - clockRadius,
                width: clockRadius * 2,
                height: clockRadius * 2
            ),
            transform: nil
        )
        
        context.addPath(backgroundPath)
        context.strokePath()
        
        context.restoreGState()
    }
    
    private func drawProgressArc(in context: CGContext, center: CGPoint, progress: Double) {
        context.saveGState()
        
        // 设置进度弧颜色和样式
        context.setStrokeColor(NSColor.controlAccentColor.cgColor)
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        
        // 计算角度（从12点开始，顺时针）
        let startAngle = -CGFloat.pi / 2  // 12点位置
        let endAngle = startAngle + CGFloat(progress * 2 * Double.pi)
        
        // 绘制进度弧
        context.addArc(
            center: center,
            radius: clockRadius - 1,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        
        context.strokePath()
        
        context.restoreGState()
    }
    
    private func drawClockHand(in context: CGContext, center: CGPoint, progress: Double) {
        context.saveGState()
        
        // 设置指针颜色和样式
        context.setStrokeColor(NSColor.labelColor.cgColor)
        context.setLineWidth(handWidth)
        context.setLineCap(.round)
        
        // 计算指针角度（从12点开始，顺时针）
        let angle = -CGFloat.pi / 2 + CGFloat(progress * 2 * Double.pi)
        
        // 计算指针终点
        let handLength = clockRadius * 0.7
        let handEndX = center.x + cos(angle) * handLength
        let handEndY = center.y + sin(angle) * handLength
        
        // 绘制指针
        context.move(to: center)
        context.addLine(to: CGPoint(x: handEndX, y: handEndY))
        context.strokePath()
        
        context.restoreGState()
    }
    
    private func drawCenterDot(in context: CGContext, center: CGPoint) {
        context.saveGState()
        
        // 设置中心点颜色
        context.setFillColor(NSColor.labelColor.cgColor)
        
        // 绘制中心圆点
        let dotRadius: CGFloat = 1.5
        let dotPath = CGPath(
            ellipseIn: CGRect(
                x: center.x - dotRadius,
                y: center.y - dotRadius,
                width: dotRadius * 2,
                height: dotRadius * 2
            ),
            transform: nil
        )
        
        context.addPath(dotPath)
        context.fillPath()
        
        context.restoreGState()
    }
    
    // MARK: - Large Size Drawing Methods
    
    private func drawLargeClockBackground(in context: CGContext, center: CGPoint, radius: CGFloat, lineWidth: CGFloat) {
        context.saveGState()
        
        // 设置背景圆圈颜色和样式
        context.setStrokeColor(NSColor.controlAccentColor.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(lineWidth * 0.5)
        
        // 绘制外圆
        let backgroundPath = CGPath(
            ellipseIn: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ),
            transform: nil
        )
        
        context.addPath(backgroundPath)
        context.strokePath()
        
        context.restoreGState()
    }
    
    private func drawLargeProgressArc(in context: CGContext, center: CGPoint, radius: CGFloat, lineWidth: CGFloat, progress: Double) {
        context.saveGState()
        
        // 设置进度弧颜色和样式
        context.setStrokeColor(NSColor.controlAccentColor.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        
        // 计算角度（从12点开始，顺时针）
        let startAngle = -CGFloat.pi / 2  // 12点位置
        let endAngle = startAngle + CGFloat(progress * 2 * Double.pi)
        
        // 绘制进度弧
        context.addArc(
            center: center,
            radius: radius - lineWidth / 2,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        
        context.strokePath()
        
        context.restoreGState()
    }
    
    private func drawLargeClockHand(in context: CGContext, center: CGPoint, radius: CGFloat, lineWidth: CGFloat, progress: Double) {
        context.saveGState()
        
        // 设置指针颜色和样式
        context.setStrokeColor(NSColor.labelColor.cgColor)
        context.setLineWidth(lineWidth * 0.75)
        context.setLineCap(.round)
        
        // 计算指针角度（从12点开始，顺时针）
        let angle = -CGFloat.pi / 2 + CGFloat(progress * 2 * Double.pi)
        
        // 计算指针终点
        let handLength = radius * 0.7
        let handEndX = center.x + cos(angle) * handLength
        let handEndY = center.y + sin(angle) * handLength
        
        // 绘制指针
        context.move(to: center)
        context.addLine(to: CGPoint(x: handEndX, y: handEndY))
        context.strokePath()
        
        context.restoreGState()
    }
    
    private func drawLargeCenterDot(in context: CGContext, center: CGPoint, radius: CGFloat) {
        context.saveGState()
        
        // 设置中心点颜色
        context.setFillColor(NSColor.labelColor.cgColor)
        
        // 绘制中心圆点
        let dotRadius = radius * 0.1
        let dotPath = CGPath(
            ellipseIn: CGRect(
                x: center.x - dotRadius,
                y: center.y - dotRadius,
                width: dotRadius * 2,
                height: dotRadius * 2
            ),
            transform: nil
        )
        
        context.addPath(dotPath)
        context.fillPath()
        
        context.restoreGState()
    }
    
    /// 生成简单的文字图标（备选方案）
    /// - Parameter timeString: 时间字符串
    /// - Returns: NSImage对象
    func generateTextIcon(timeString: String) -> NSImage {
        let image = NSImage(size: iconSize)
        
        image.lockFocus()
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium),
            .foregroundColor: NSColor.labelColor
        ]
        
        let attributedString = NSAttributedString(string: timeString, attributes: attributes)
        let size = attributedString.size()
        
        let drawRect = CGRect(
            x: (iconSize.width - size.width) / 2,
            y: (iconSize.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
        
        attributedString.draw(in: drawRect)
        
        image.unlockFocus()
        
        // 设置为模板图像
        image.isTemplate = true
        
        return image
    }
}
