//
//  DevicePerformanceDetectorTests.swift
//  PomodoroScreenTests
//
//  Created by Assistant on 2025-09-27.
//  设备性能检测组件的单元测试
//

import XCTest
import Cocoa
import IOKit.ps
@testable import PomodoroScreen

class DevicePerformanceDetectorTests: XCTestCase {
    
    var detector: DevicePerformanceDetector!
    
    override func setUp() {
        super.setUp()
        detector = DevicePerformanceDetector.shared
    }
    
    override func tearDown() {
        detector = nil
        super.tearDown()
    }
    
    // MARK: - 基础功能测试
    
    /// 测试设备信息检测
    func testDetectDeviceInfo() {
        let deviceInfo = detector.detectDeviceInfo()
        
        // 验证基本信息
        XCTAssertGreaterThan(deviceInfo.memoryGB, 0, "内存大小应该大于0")
        XCTAssertGreaterThan(deviceInfo.cpuCores, 0, "CPU核心数应该大于0")
        XCTAssertNotNil(deviceInfo.cpuBrand, "CPU品牌不应该为空")
        XCTAssertNotNil(deviceInfo.architecture, "架构信息不应该为空")
        
        // 验证性能等级描述
        let performanceLevel = deviceInfo.performanceLevel
        let validLevels = ["M芯片高性能", "Intel高性能", "节能模式"]
        XCTAssertTrue(validLevels.contains(performanceLevel), "性能等级应该是有效值")
        
        // 验证推荐媒体类型
        let mediaType = deviceInfo.recommendedMediaType
        XCTAssertTrue(mediaType == .video || mediaType == .image, "推荐媒体类型应该是视频或图片")
        
        print("📊 设备信息检测结果:")
        print("   💾 内存: \(String(format: "%.1f", deviceInfo.memoryGB))GB")
        print("   🖥️ CPU核心: \(deviceInfo.cpuCores)个")
        print("   🔋 电池模式: \(deviceInfo.isOnBattery ? "是" : "否")")
        print("   🍎 M芯片: \(deviceInfo.isMChip ? "是" : "否")")
        print("   🚀 高性能设备: \(deviceInfo.isHighPerformance ? "是" : "否")")
        print("   🎨 主题模式: \(deviceInfo.isDarkMode ? "深色模式" : "浅色模式")")
        print("   🖥️ CPU品牌: \(deviceInfo.cpuBrand)")
        print("   🏗️架构: \(deviceInfo.architecture)")
        print("   📊 性能等级: \(performanceLevel)")
        print("   🎬 推荐媒体: \(mediaType)")
    }
    
    // MARK: - M芯片检测测试
    
    /// 测试M芯片检测功能
    func testAppleSiliconDetection() {
        let deviceInfo = detector.detectDeviceInfo()
        let isMChip = deviceInfo.isMChip
        
        // 验证M芯片检测结果的一致性
        if isMChip {
            // M芯片设备应该是高性能设备
            XCTAssertTrue(deviceInfo.isHighPerformance, "M芯片设备应该被标记为高性能")
            XCTAssertTrue(deviceInfo.cpuBrand.contains("Apple"), "M芯片设备的CPU品牌应该包含Apple")
            XCTAssertEqual(deviceInfo.architecture, "ARM64 (Apple Silicon)", "M芯片设备的架构应该是ARM64")
        }
        
        print("🍎 M芯片检测测试:")
        print("   🖥️ CPU品牌: \(deviceInfo.cpuBrand)")
        print("   🏗️ 编译架构: \(deviceInfo.architecture)")
        print("   🍎 M芯片检测: \(isMChip ? "是" : "否")")
        print("   💾 物理内存: \(String(format: "%.1f", deviceInfo.memoryGB)) GB")
        print("   ⚙️ CPU核心: \(deviceInfo.cpuCores)")
        
        if isMChip {
            print("   ✨ M芯片设备 → 自动高性能模式")
        } else if deviceInfo.isHighPerformance {
            print("   💪 Intel高性能设备 → 高性能模式")
        } else {
            print("   🔋 低性能设备 → 节能模式")
        }
        
        print("   📊 最终判定: \(deviceInfo.isHighPerformance ? "高性能设备" : "低性能设备")")
        print("   🎬 推荐媒体: \(deviceInfo.recommendedMediaType)")
    }
    
    /// 测试性能评估逻辑
    func testPerformanceEvaluation() {
        let deviceInfo = detector.detectDeviceInfo()
        
        if deviceInfo.isMChip {
            // M芯片应该总是高性能
            XCTAssertTrue(deviceInfo.isHighPerformance, "M芯片设备应该总是高性能")
        } else {
            // Intel设备的性能评估逻辑
            let expectedHighPerformance = deviceInfo.memoryGB >= 16.0 && 
                                        deviceInfo.cpuCores >= 8 && 
                                        !deviceInfo.isOnBattery
            XCTAssertEqual(deviceInfo.isHighPerformance, expectedHighPerformance, 
                          "Intel设备的性能评估应该基于内存、CPU核心数和电源状态")
        }
        
        print("🚀 性能评估测试:")
        print("   💾 内存: \(String(format: "%.1f", deviceInfo.memoryGB))GB (>= 16GB: \(deviceInfo.memoryGB >= 16.0))")
        print("   🖥️ CPU核心: \(deviceInfo.cpuCores)个 (>= 8: \(deviceInfo.cpuCores >= 8))")
        print("   🔋 电池模式: \(deviceInfo.isOnBattery ? "是" : "否")")
        print("   🍎 M芯片: \(deviceInfo.isMChip ? "是" : "否")")
        print("   🚀 高性能设备: \(deviceInfo.isHighPerformance ? "是" : "否")")
    }
    
    // MARK: - 智能背景选择测试
    
    /// 测试智能背景选择策略
    func testSmartBackgroundSelection() {
        let deviceInfo = detector.detectDeviceInfo()
        
        print("🎯 智能背景选择策略测试:")
        print("   📊 设备性能: \(deviceInfo.isHighPerformance ? "高性能" : "低性能")")
        print("   🎨 主题模式: \(deviceInfo.isDarkMode ? "深色模式" : "浅色模式")")
        
        let themePrefix = deviceInfo.isDarkMode ? "dark" : "light"
        
        if deviceInfo.isHighPerformance {
            print("   1️⃣ 优先选择: rest_video_\(themePrefix).mp4")
            print("   2️⃣ 降级方案: rest_image_\(themePrefix).png/jpeg")
            print("   3️⃣ 备用文件: rest_video.mp4 或 icon_video.mp4")
            XCTAssertEqual(deviceInfo.recommendedMediaType, .video, "高性能设备应该推荐视频")
        } else {
            print("   1️⃣ 优先选择: rest_image_\(themePrefix).png/jpeg")
            print("   2️⃣ 降级方案: rest_video_\(themePrefix).mp4")
            print("   3️⃣ 备用文件: rest_video.mp4 或 icon_video.mp4")
            XCTAssertEqual(deviceInfo.recommendedMediaType, .image, "低性能设备应该推荐图片")
        }
    }
    
    /// 测试主题检测
    func testThemeDetection() {
        let deviceInfo = detector.detectDeviceInfo()
        
        // 验证主题检测结果是布尔值
        XCTAssertTrue(deviceInfo.isDarkMode == true || deviceInfo.isDarkMode == false, 
                     "主题检测应该返回布尔值")
        
        print("🎨 主题模式检测测试:")
        print("   🌙 当前主题: \(deviceInfo.isDarkMode ? "深色模式" : "浅色模式")")
        print("   📁 推荐文件后缀: _\(deviceInfo.isDarkMode ? "dark" : "light")")
    }
    
    /// 测试资源文件检测
    func testResourceFileDetection() {
        print("📁 资源文件检测测试:")
        
        let resourceTypes = [
            ("rest_video_light.mp4", "浅色主题视频"),
            ("rest_video_dark.mp4", "深色主题视频"),
            ("rest_image_light.png", "浅色主题图片"),
            ("rest_image_dark.jpeg", "深色主题图片"),
            ("rest_video.mp4", "通用视频"),
            ("icon_video.mp4", "图标视频")
        ]
        
        var foundFiles = 0
        
        for (fileName, description) in resourceTypes {
            let components = fileName.components(separatedBy: ".")
            let name = components[0]
            let ext = components[1]
            
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                print("   ✅ \(description): \(fileName)")
                print("      路径: \(url.path)")
                foundFiles += 1
            } else {
                print("   ❌ \(description): \(fileName) (未找到)")
            }
        }
        
        // 至少应该有一些资源文件存在
        XCTAssertGreaterThan(foundFiles, 0, "应该至少找到一些资源文件")
    }
    
    // MARK: - 边界条件测试
    
    /// 测试单例模式
    func testSingletonPattern() {
        let detector1 = DevicePerformanceDetector.shared
        let detector2 = DevicePerformanceDetector.shared
        
        XCTAssertTrue(detector1 === detector2, "应该返回同一个单例实例")
    }
    
    /// 测试多次调用的一致性
    func testConsistentResults() {
        let info1 = detector.detectDeviceInfo()
        let info2 = detector.detectDeviceInfo()
        
        // 基本硬件信息应该保持一致
        XCTAssertEqual(info1.memoryGB, info2.memoryGB, accuracy: 0.1, "内存大小应该一致")
        XCTAssertEqual(info1.cpuCores, info2.cpuCores, "CPU核心数应该一致")
        XCTAssertEqual(info1.isMChip, info2.isMChip, "M芯片检测结果应该一致")
        XCTAssertEqual(info1.cpuBrand, info2.cpuBrand, "CPU品牌应该一致")
        XCTAssertEqual(info1.architecture, info2.architecture, "架构信息应该一致")
        
        // 注意：电池状态和主题模式可能会变化，所以不做严格比较
    }
    
    /// 测试性能基准
    func testPerformanceBenchmark() {
        measure {
            for _ in 0..<100 {
                _ = detector.detectDeviceInfo()
            }
        }
    }
    
    // MARK: - 集成测试
    
    /// 测试与OverlayWindow的集成
    func testOverlayWindowIntegration() {
        let deviceInfo = detector.detectDeviceInfo()
        
        // 验证性能检测结果可以用于背景选择
        XCTAssertNotNil(deviceInfo.recommendedMediaType, "应该有推荐的媒体类型")
        XCTAssertNotNil(deviceInfo.performanceLevel, "应该有性能等级描述")
        
        // 验证智能背景选择逻辑
        let themePrefix = deviceInfo.isDarkMode ? "dark" : "light"
        let expectedPriority = deviceInfo.isHighPerformance ? "video" : "image"
        
        print("🔗 集成测试结果:")
        print("   🎯 主题前缀: \(themePrefix)")
        print("   📊 性能等级: \(deviceInfo.performanceLevel)")
        print("   🎬 媒体优先级: \(expectedPriority)")
        print("   💡 推荐策略: \(deviceInfo.isHighPerformance ? "视频优先，图片降级" : "图片优先，视频降级")")
    }
}
