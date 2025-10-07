//
//  IconRenderer.swift
//  PomodoroScreen
//
//  Created by Assistant on 2025-10-07.
//

import Cocoa

enum IconRenderer {
    /// 生成垂直居中的 SF Symbol 图标，画布高度与文字行高一致
    /// - Parameters:
    ///   - systemName: SF Symbol 名称
    ///   - font: 参考字体（用于计算行高和 pointSize）
    ///   - weight: 符号粗细（默认 regular）
    ///   - horizontalPadding: 水平内边距，避免贴边
    /// - Returns: NSImage（模板图像），根据字体行高垂直居中
    static func centeredSymbolImage(systemName: String,
                                    font: NSFont,
                                    weight: NSFont.Weight = .regular,
                                    horizontalPadding: CGFloat = 2) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: font.pointSize, weight: weight)
        guard let base = NSImage(systemSymbolName: systemName, accessibilityDescription: systemName)?.withSymbolConfiguration(config) else {
            return NSImage(systemSymbolName: systemName, accessibilityDescription: systemName)
        }
        let lineHeight = font.boundingRectForFont.size.height
        let canvasSize = CGSize(width: max(16, base.size.width + horizontalPadding * 2), height: lineHeight)
        let canvas = NSImage(size: canvasSize)
        canvas.lockFocus()
        let drawSize = base.size
        let x = (canvasSize.width - drawSize.width) / 2
        let y = (canvasSize.height - drawSize.height) / 2
        base.draw(in: NSRect(x: x, y: y, width: drawSize.width, height: drawSize.height))
        canvas.unlockFocus()
        canvas.isTemplate = true
        return canvas
    }
}


