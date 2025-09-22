//
//  ClockIconGenerator.swift
//  PomodoroScreen
//
//  Created by Assistant on 2025-09-22.
//

import Cocoa

class ClockIconGenerator {
    
    // MARK: - Properties
    
    private let iconSize: CGSize = CGSize(width: 20, height: 20)
    private let clockRadius: CGFloat = 8
    private let handWidth: CGFloat = 1.5
    
    // MARK: - Public Methods
    
    /// 生成时钟样式的状态栏图标
    /// - Parameters:
    ///   - progress: 倒计时进度 (0.0 - 1.0)，0表示开始，1表示结束
    ///   - totalTime: 总时间（秒）
    ///   - remainingTime: 剩余时间（秒）
    /// - Returns: NSImage对象
    func generateClockIcon(progress: Double, totalTime: TimeInterval, remainingTime: TimeInterval) -> NSImage {
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
