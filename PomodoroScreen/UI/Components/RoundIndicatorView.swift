//
//  RoundIndicatorView.swift
//  PomodoroScreen
//
//  Created by jake on 2025/9/23.
//

import Cocoa

// MARK: - Round Indicator View

class RoundIndicatorView: NSView {
    private var completedRounds: Int = 0
    private var longBreakCycle: Int = 2  // 每2轮进行一次长休息
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.wantsLayer = true
    }
    
    func updateRounds(completed: Int, cycle: Int = 2) {
        self.completedRounds = completed
        self.longBreakCycle = cycle
        self.needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // 清除背景
        context.clear(bounds)
        
        // 计算指示点的布局
        let totalWidth = bounds.width
        let totalHeight = bounds.height
        
        // 每个周期的指示点数量 = longBreakCycle个短休息 + 1个长休息
        let indicatorsPerCycle = longBreakCycle + 1
        
        // 短休息指示点尺寸（方形）
        let shortIndicatorSize: CGFloat = 4
        let longIndicatorWidth: CGFloat = 8  // 长休息指示点宽度（长方形）
        let longIndicatorHeight: CGFloat = 4
        let spacing: CGFloat = 4
        
        // 计算一个完整周期的总宽度
        let cycleWidth = CGFloat(longBreakCycle) * shortIndicatorSize + longIndicatorWidth + CGFloat(longBreakCycle) * spacing
        
        // 居中起始位置
        let startX = (totalWidth - cycleWidth) / 2
        let centerY = totalHeight / 2
        
        var currentX = startX
        
        // 绘制指示点
        for i in 0..<indicatorsPerCycle {
            let isLongBreak = (i == longBreakCycle)  // 最后一个是长休息
            let indicatorIndex = i
            
            // 计算当前轮数在周期中的位置
            let currentRoundInCycle = completedRounds % indicatorsPerCycle
            let isCompleted = indicatorIndex < currentRoundInCycle
            let isCurrent = indicatorIndex == currentRoundInCycle
            
            if isLongBreak {
                // 绘制长休息指示点（长方形）
                let rect = NSRect(
                    x: currentX,
                    y: centerY - longIndicatorHeight / 2,
                    width: longIndicatorWidth,
                    height: longIndicatorHeight
                )
                
                drawIndicator(context: context, rect: rect, isCompleted: isCompleted, isCurrent: isCurrent, isLongBreak: true)
                currentX += longIndicatorWidth + spacing
            } else {
                // 绘制短休息指示点（方形）
                let rect = NSRect(
                    x: currentX,
                    y: centerY - shortIndicatorSize / 2,
                    width: shortIndicatorSize,
                    height: shortIndicatorSize
                )
                
                drawIndicator(context: context, rect: rect, isCompleted: isCompleted, isCurrent: isCurrent, isLongBreak: false)
                currentX += shortIndicatorSize + spacing
            }
        }
    }
    
    private func drawIndicator(context: CGContext, rect: NSRect, isCompleted: Bool, isCurrent: Bool, isLongBreak: Bool) {
        let cornerRadius: CGFloat = isLongBreak ? 2 : 3
        
        // 选择颜色
        var fillColor: NSColor
        var strokeColor: NSColor
        
        if isCompleted {
            // 已完成：蓝色填充
            fillColor = NSColor.controlAccentColor
            strokeColor = NSColor.controlAccentColor
        } else if isCurrent {
            // 当前进行中：橙色填充
            fillColor = NSColor.systemOrange
            strokeColor = NSColor.systemOrange
        } else {
            // 未开始：灰色边框，无填充
            fillColor = NSColor.clear
            strokeColor = NSColor.tertiaryLabelColor
        }
        
        // 绘制背景
        context.saveGState()
        context.setFillColor(fillColor.cgColor)
        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(1.0)
        
        // 绘制圆角矩形
        let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        path.fill()
        
        if fillColor == NSColor.clear {
            path.stroke()
        }
        
        context.restoreGState()
    }
}
