//
//  MultiScreenOverlayManager.swift
//  PomodoroScreen
//
//  Created by Assistant on 2025-09-27.
//

import Cocoa

class MultiScreenOverlayManager {
    
    // MARK: - Properties
    
    private var overlayWindows: [OverlayWindow] = []
    private var timer: PomodoroTimer?
    private var isPreviewMode: Bool = false
    private var previewFiles: [BackgroundFile] = []
    private var selectedIndex: Int = 0
    
    // MARK: - Initialization
    
    init(timer: PomodoroTimer) {
        self.timer = timer
        self.isPreviewMode = false
        
        // 监听屏幕配置变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    init(previewFiles: [BackgroundFile], selectedIndex: Int = 0) {
        self.isPreviewMode = true
        self.previewFiles = previewFiles
        self.selectedIndex = selectedIndex
        
        // 监听屏幕配置变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        hideAllOverlays()
    }
    
    // MARK: - Public Methods
    
    func showOverlaysOnAllScreens() {
        print("🖥️ 开始在所有屏幕上显示遮罩层")
        
        // 清理现有的遮罩窗口
        hideAllOverlays()
        
        // 获取所有屏幕
        let screens = NSScreen.screens
        print("   📺 检测到 \(screens.count) 个屏幕")
        
        // 为每个屏幕创建遮罩窗口
        for (index, screen) in screens.enumerated() {
            print("   🔍 正在为屏幕 \(index + 1) 创建遮罩窗口")
            print("      - 屏幕尺寸: \(screen.frame)")
            print("      - 是否主屏幕: \(screen == NSScreen.main)")
            print("      - 可见区域: \(screen.visibleFrame)")
            
            let overlayWindow = createOverlayWindow(for: screen, screenIndex: index)
            overlayWindows.append(overlayWindow)
            
            // 立即显示遮罩
            print("   🎬 开始显示屏幕 \(index + 1) 的遮罩")
            overlayWindow.showOverlay()
            
            // 多重显示策略确保窗口可见
            overlayWindow.makeKeyAndOrderFront(nil)
            overlayWindow.orderFrontRegardless()
            
            // 验证窗口状态
            print("      - 窗口是否可见: \(overlayWindow.isVisible)")
            print("      - 窗口层级: \(overlayWindow.level.rawValue)")
            print("      - 窗口位置: \(overlayWindow.frame)")
            
            // 延迟再次确保显示
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if !overlayWindow.isVisible {
                    print("   ⚠️ 屏幕 \(index + 1) 窗口不可见，尝试强制显示")
                    overlayWindow.orderFront(nil)
                    overlayWindow.makeKeyAndOrderFront(nil)
                    overlayWindow.orderFrontRegardless()
                }
                print("   ✅ 屏幕 \(index + 1) 最终状态检查完成")
            }
        }
        
        print("✅ 已在 \(overlayWindows.count) 个屏幕上显示遮罩层")
    }
    
    func hideAllOverlays() {
        print("🔄 隐藏所有屏幕上的遮罩层")
        
        for overlayWindow in overlayWindows {
            overlayWindow.orderOut(nil)
        }
        
        overlayWindows.removeAll()
        print("✅ 已隐藏所有遮罩层")
    }
    
    func updateOverlaysForScreenChanges() {
        guard !overlayWindows.isEmpty else { return }
        
        print("🔄 屏幕配置发生变化，更新遮罩层")
        
        // 重新显示所有遮罩
        showOverlaysOnAllScreens()
    }
    
    // MARK: - Private Methods
    
    private func createOverlayWindow(for screen: NSScreen, screenIndex: Int) -> OverlayWindow {
        print("      🔧 创建窗口对象...")
        let overlayWindow: OverlayWindow
        
        if isPreviewMode {
            // 预览模式
            overlayWindow = OverlayWindow(previewFiles: previewFiles, selectedIndex: selectedIndex)
            print("      📋 预览模式窗口已创建")
        } else {
            // 正常模式
            overlayWindow = OverlayWindow(timer: timer!)
            print("      ⏰ 正常模式窗口已创建")
        }
        
        // 设置窗口位置和大小为当前屏幕
        print("      📐 设置窗口尺寸: \(screen.frame)")
        overlayWindow.setFrame(screen.frame, display: true)
        
        // 确保窗口在正确的屏幕上
        if let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            print("      🎯 目标屏幕设备号: \(screenNumber)")
        }
        
        // 设置窗口属性以支持多屏幕
        overlayWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        print("      🔄 窗口行为已设置: canJoinAllSpaces, fullScreenAuxiliary, ignoresCycle")
        
        // 为所有屏幕设置相同的高层级
        overlayWindow.level = .screenSaver
        print("      📊 窗口层级设置为: \(NSWindow.Level.screenSaver.rawValue)")
        
        // 确保窗口不忽略鼠标事件
        overlayWindow.ignoresMouseEvents = false
        
        // 设置窗口为不透明以确保可见性
        overlayWindow.isOpaque = false
        overlayWindow.backgroundColor = NSColor.clear
        print("      🎨 窗口透明度和背景已设置")
        
        // 为非主屏幕添加额外的显示保证
        if screen != NSScreen.main {
            print("      🖥️ 配置辅助屏幕窗口 (非主屏幕)")
            // 强制窗口在指定屏幕上显示
            overlayWindow.setFrameOrigin(screen.frame.origin)
            print("      📍 强制设置窗口原点: \(screen.frame.origin)")
            
            // 尝试更激进的显示策略
            overlayWindow.level = .modalPanel  // 更高的层级
            overlayWindow.hidesOnDeactivate = false
            overlayWindow.canHide = false
            print("      🚀 辅助屏幕使用更高层级: modalPanel")
        } else {
            print("      🖥️ 主屏幕窗口配置")
        }
        
        print("      ✅ 窗口创建完成")
        return overlayWindow
    }
    
    @objc private func screenConfigurationChanged() {
        print("📺 屏幕配置发生变化")
        
        // 延迟一点时间再更新，确保系统完成屏幕配置
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.updateOverlaysForScreenChanges()
        }
    }
    
    // MARK: - Screen Information
    
    func getScreenInfo() -> [String: Any] {
        let screens = NSScreen.screens
        var screenInfo: [[String: Any]] = []
        
        for (index, screen) in screens.enumerated() {
            let info: [String: Any] = [
                "index": index,
                "frame": NSStringFromRect(screen.frame),
                "visibleFrame": NSStringFromRect(screen.visibleFrame),
                "isMain": screen == NSScreen.main,
                "backingScaleFactor": screen.backingScaleFactor,
                "deviceDescription": screen.deviceDescription
            ]
            screenInfo.append(info)
        }
        
        return [
            "screenCount": screens.count,
            "screens": screenInfo
        ]
    }
}

// MARK: - OverlayWindow Extension for Multi-Screen Support

extension OverlayWindow {
    
    // 为特定屏幕创建遮罩窗口的便利初始化方法
    convenience init(timer: PomodoroTimer, for screen: NSScreen) {
        self.init(timer: timer)
        
        // 设置窗口位置和大小为指定屏幕
        self.setFrame(screen.frame, display: false)
        
        // 确保窗口属性适合多屏幕环境
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        
        print("🖼️ 为屏幕创建遮罩窗口: \(screen.frame)")
    }
    
    convenience init(previewFiles: [BackgroundFile], selectedIndex: Int = 0, for screen: NSScreen) {
        self.init(previewFiles: previewFiles, selectedIndex: selectedIndex)
        
        // 设置窗口位置和大小为指定屏幕
        self.setFrame(screen.frame, display: false)
        
        // 确保窗口属性适合多屏幕环境
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        
        print("🖼️ 为屏幕创建预览遮罩窗口: \(screen.frame)")
    }
}
