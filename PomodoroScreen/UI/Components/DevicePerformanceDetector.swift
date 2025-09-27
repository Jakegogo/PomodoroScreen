//
//  DevicePerformanceDetector.swift
//  PomodoroScreen
//
//  Created by Assistant on 2025-09-27.
//  设备性能检测组件
//

import Cocoa
import IOKit.ps

/// 设备性能检测器
/// 
/// 功能特性:
/// - 检测Mac设备类型（M芯片 vs Intel）
/// - 评估设备性能等级（高性能 vs 低性能）
/// - 检测电源状态（电池 vs 外接电源）
/// - 获取系统硬件信息（内存、CPU核心数）
/// - 支持主题模式检测（深色 vs 浅色）
///
/// 使用示例:
/// ```swift
/// let detector = DevicePerformanceDetector()
/// let info = detector.detectDeviceInfo()
/// 
/// if info.isHighPerformance {
///     // 使用高性能设置
/// } else {
///     // 使用节能设置
/// }
/// ```
class DevicePerformanceDetector {
    
    // MARK: - Data Models
    
    /// 设备信息结构体
    struct DeviceInfo {
        let memoryGB: Double
        let cpuCores: Int
        let isOnBattery: Bool
        let isMChip: Bool
        let isHighPerformance: Bool
        let isDarkMode: Bool
        let cpuBrand: String
        let architecture: String
        
        /// 性能等级描述
        var performanceLevel: String {
            if isMChip {
                return "M芯片高性能"
            } else if isHighPerformance {
                return "Intel高性能"
            } else {
                return "节能模式"
            }
        }
        
        /// 推荐媒体类型
        var recommendedMediaType: MediaType {
            return isHighPerformance ? .video : .image
        }
    }
    
    /// 媒体类型枚举
    enum MediaType {
        case video
        case image
        
        var description: String {
            switch self {
            case .video: return "视频优先"
            case .image: return "图片优先"
            }
        }
    }
    
    // MARK: - Singleton
    
    static let shared = DevicePerformanceDetector()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 检测设备信息
    /// - Parameter verbose: 是否输出详细日志
    /// - Returns: 设备信息结构体
    func detectDeviceInfo(verbose: Bool = true) -> DeviceInfo {
        let memoryGB = getPhysicalMemoryGB()
        let cpuCores = ProcessInfo.processInfo.processorCount
        let isOnBattery = isRunningOnBattery()
        let isMChip = isMacWithAppleSilicon()
        let isDarkMode = detectThemeMode()
        let cpuBrand = getCPUBrand()
        let architecture = getArchitecture()
        
        // 性能评估逻辑
        let isHighPerformance: Bool
        if isMChip {
            // M芯片Mac默认为高性能设备
            isHighPerformance = true
        } else {
            // Intel Mac使用传统检测标准：内存 > 16GB 且 CPU核心 >= 8 且不在电池模式
            isHighPerformance = memoryGB >= 16.0 && cpuCores >= 8 && !isOnBattery
        }
        
        let deviceInfo = DeviceInfo(
            memoryGB: memoryGB,
            cpuCores: cpuCores,
            isOnBattery: isOnBattery,
            isMChip: isMChip,
            isHighPerformance: isHighPerformance,
            isDarkMode: isDarkMode,
            cpuBrand: cpuBrand,
            architecture: architecture
        )
        
        if verbose {
            logDeviceInfo(deviceInfo)
        }
        
        return deviceInfo
    }
    
    /// 快速检测是否为高性能设备
    /// - Returns: 是否为高性能设备
    func isHighPerformanceDevice() -> Bool {
        return detectDeviceInfo(verbose: false).isHighPerformance
    }
    
    /// 快速检测是否为M芯片设备
    /// - Returns: 是否为M芯片设备
    func isMacWithAppleSilicon() -> Bool {
        return detectAppleSilicon()
    }
    
    /// 快速检测当前主题模式
    /// - Returns: 是否为深色模式
    func isDarkMode() -> Bool {
        return detectThemeMode()
    }
    
    // MARK: - Private Detection Methods
    
    /// 获取物理内存大小（GB）
    private func getPhysicalMemoryGB() -> Double {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        return Double(physicalMemory) / (1024.0 * 1024.0 * 1024.0)
    }
    
    /// 检测是否使用电池供电
    private func isRunningOnBattery() -> Bool {
        let powerSourceInfo = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
        guard let powerSources = IOPSCopyPowerSourcesList(powerSourceInfo)?.takeRetainedValue() as? [CFTypeRef] else {
            return false
        }
        
        for powerSource in powerSources {
            if let powerSourceDict = IOPSGetPowerSourceDescription(powerSourceInfo, powerSource)?.takeUnretainedValue() as? [String: Any] {
                if let powerSourceState = powerSourceDict[kIOPSPowerSourceStateKey] as? String {
                    return powerSourceState == kIOPSBatteryPowerValue
                }
            }
        }
        return false
    }
    
    /// 检测是否为Apple Silicon (M芯片) Mac
    private func detectAppleSilicon() -> Bool {
        // 主要检测方法：hw.optional.arm64
        var size = 0
        sysctlbyname("hw.optional.arm64", nil, &size, nil, 0)
        
        if size > 0 {
            var result: Int32 = 0
            var resultSize = MemoryLayout<Int32>.size
            let status = sysctlbyname("hw.optional.arm64", &result, &resultSize, nil, 0)
            
            if status == 0 {
                return result == 1
            }
        }
        
        // 备用检测方法：通过CPU品牌名称
        let cpuBrand = getCPUBrand()
        return cpuBrand.contains("Apple")
    }
    
    /// 检测系统主题模式
    private func detectThemeMode() -> Bool {
        let appearance = NSApp.effectiveAppearance
        return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
    
    /// 获取CPU品牌信息
    private func getCPUBrand() -> String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        
        if size > 0 {
            var brandString = [CChar](repeating: 0, count: size)
            let status = sysctlbyname("machdep.cpu.brand_string", &brandString, &size, nil, 0)
            
            if status == 0 {
                return String(cString: brandString)
            }
        }
        
        return "未知"
    }
    
    /// 获取系统架构信息
    private func getArchitecture() -> String {
        #if arch(arm64)
        return "ARM64 (Apple Silicon)"
        #elseif arch(x86_64)
        return "x86_64 (Intel)"
        #else
        return "未知架构"
        #endif
    }
    
    // MARK: - Logging
    
    /// 输出设备信息日志
    private func logDeviceInfo(_ info: DeviceInfo) {
        print("🔍 设备性能检测:")
        print("   💾 内存: \(String(format: "%.1f", info.memoryGB))GB")
        print("   🖥️ CPU核心: \(info.cpuCores)个")
        print("   🔋 电池模式: \(info.isOnBattery ? "是" : "否")")
        print("   🍎 M芯片: \(info.isMChip ? "是" : "否")")
        print("   🚀 高性能设备: \(info.isHighPerformance ? "是" : "否")")
        print("   🎨 主题模式: \(info.isDarkMode ? "深色模式" : "浅色模式")")
        print("   🖥️ CPU品牌: \(info.cpuBrand)")
        print("   🏗️ 架构: \(info.architecture)")
        
        if info.isMChip {
            print("   ✨ M芯片检测：自动启用高性能模式")
        }
        
        print("   📊 性能等级: \(info.performanceLevel)")
        print("   🎬 推荐媒体: \(info.recommendedMediaType.description)")
    }
}

// MARK: - Extensions

extension DevicePerformanceDetector {
    
    /// 获取性能检测摘要
    func getPerformanceSummary() -> String {
        let info = detectDeviceInfo(verbose: false)
        
        var summary = "设备性能摘要:\n"
        summary += "• 设备类型: \(info.isMChip ? "Apple Silicon" : "Intel Mac")\n"
        summary += "• 内存: \(String(format: "%.1f", info.memoryGB))GB\n"
        summary += "• CPU: \(info.cpuCores)核心\n"
        summary += "• 电源: \(info.isOnBattery ? "电池" : "外接电源")\n"
        summary += "• 性能等级: \(info.performanceLevel)\n"
        summary += "• 推荐设置: \(info.recommendedMediaType.description)"
        
        return summary
    }
    
    /// 检查设备是否满足最低性能要求
    /// - Parameter requirements: 性能要求
    /// - Returns: 是否满足要求
    func meetsPerformanceRequirements(_ requirements: PerformanceRequirements) -> Bool {
        let info = detectDeviceInfo(verbose: false)
        
        return info.memoryGB >= requirements.minMemoryGB &&
               info.cpuCores >= requirements.minCPUCores &&
               (!requirements.requiresExternalPower || !info.isOnBattery)
    }
}

// MARK: - Performance Requirements

/// 性能要求结构体
struct PerformanceRequirements {
    let minMemoryGB: Double
    let minCPUCores: Int
    let requiresExternalPower: Bool
    
    /// 视频播放的推荐要求
    static let videoPlayback = PerformanceRequirements(
        minMemoryGB: 8.0,
        minCPUCores: 4,
        requiresExternalPower: false
    )
    
    /// 高性能模式的要求
    static let highPerformance = PerformanceRequirements(
        minMemoryGB: 16.0,
        minCPUCores: 8,
        requiresExternalPower: true
    )
}
