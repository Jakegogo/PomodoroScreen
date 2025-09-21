import Foundation
import ServiceManagement

/// 开机自启动管理类
/// 
/// 作者: AI Assistant
/// 创建时间: 2024-09-21
/// 
/// 管理应用的开机自启动功能，使用macOS的LaunchServices框架
class LaunchAtLogin {
    
    /// 单例实例
    static let shared = LaunchAtLogin()
    
    private init() {}
    
    /// 应用的Bundle Identifier
    private var bundleIdentifier: String {
        return Bundle.main.bundleIdentifier ?? "com.pomodoroscreen.app"
    }
    
    /// 检查是否已启用开机自启动
    var isEnabled: Bool {
        get {
            // 使用UserDefaults作为主要存储，因为SMLoginItemSetEnabled在某些情况下可能不可靠
            return UserDefaults.standard.bool(forKey: "LaunchAtLoginEnabled")
        }
        set {
            setLaunchAtLogin(enabled: newValue)
        }
    }
    
    /// 设置开机自启动状态
    /// - Parameter enabled: 是否启用开机自启动
    private func setLaunchAtLogin(enabled: Bool) {
        // 保存到UserDefaults
        UserDefaults.standard.set(enabled, forKey: "LaunchAtLoginEnabled")
        
        // 使用现代API设置开机自启动
        if #available(macOS 13.0, *) {
            // 使用SMAppService (macOS 13.0+)
            setLaunchAtLoginModern(enabled: enabled)
        } else {
            // 使用SMLoginItemSetEnabled (macOS 10.6-12.x)
            setLaunchAtLoginLegacy(enabled: enabled)
        }
    }
    
    /// 使用现代API设置开机自启动 (macOS 13.0+)
    /// - Parameter enabled: 是否启用开机自启动
    @available(macOS 13.0, *)
    private func setLaunchAtLoginModern(enabled: Bool) {
        do {
            let service = SMAppService.mainApp
            
            if enabled {
                // 注册开机自启动服务
                try service.register()
                print("✅ 开机自启动设置成功: \(enabled)")
            } else {
                // 取消注册开机自启动服务
                try service.unregister()
                print("✅ 开机自启动取消成功: \(enabled)")
            }
        } catch {
            print("⚠️ 开机自启动设置失败: \(error.localizedDescription)")
            
            // 处理错误，建议手动设置
            print("错误详情: \(error)")
            showManualSetupInstructions()
        }
    }
    
    /// 为旧版macOS设置开机自启动（使用SMLoginItemSetEnabled）
    /// - Parameter enabled: 是否启用开机自启动
    private func setLaunchAtLoginLegacy(enabled: Bool) {
        print("📝 使用传统API设置开机自启动: \(enabled)")
        
        // 使用SMLoginItemSetEnabled (已弃用但在旧版本中仍可用)
        let success = SMLoginItemSetEnabled(bundleIdentifier as CFString, enabled)
        if success {
            print("✅ 开机自启动设置成功: \(enabled)")
        } else {
            print("⚠️ 开机自启动设置失败，可能需要用户手动设置")
            showManualSetupInstructions()
        }
    }
    
    
    /// 显示手动设置指导
    private func showManualSetupInstructions() {
        print("📖 手动设置开机自启动:")
        print("1. 打开\"系统偏好设置\" > \"用户与群组\"")
        print("2. 选择您的用户账户")
        print("3. 点击\"登录项\"标签")
        print("4. 点击\"+\"按钮添加PomodoroScreen应用")
    }
    
    /// 切换开机自启动状态
    func toggle() {
        isEnabled = !isEnabled
    }
    
    /// 验证当前设置状态
    /// - Returns: 返回当前的启用状态和验证信息
    func validateStatus() -> (enabled: Bool, systemEnabled: Bool?, message: String) {
        let userDefaultsEnabled = UserDefaults.standard.bool(forKey: "LaunchAtLoginEnabled")
        
        // 尝试验证系统级别的设置
        var systemEnabled: Bool? = nil
        var message = ""
        
        if #available(macOS 13.0, *) {
            // 使用SMAppService验证状态
            let service = SMAppService.mainApp
            systemEnabled = (service.status == .enabled)
            
            switch service.status {
            case .enabled:
                message = "已启用开机自启动"
            case .requiresApproval:
                message = "需要用户批准开机自启动"
            case .notRegistered:
                message = "未注册开机自启动"
            case .notFound:
                message = "服务未找到"
            @unknown default:
                message = "未知状态"
            }
        } else {
            // 对于旧版本，主要依赖UserDefaults的记录
            systemEnabled = userDefaultsEnabled
            message = userDefaultsEnabled ? "已启用开机自启动（传统API）" : "未启用开机自启动"
        }
        
        return (enabled: userDefaultsEnabled, systemEnabled: systemEnabled, message: message)
    }
    
    /// 获取设置指导信息
    /// - Returns: 返回用户设置指导
    func getSetupInstructions() -> String {
        return """
        如果自动设置失败，您可以手动设置开机自启动：
        
        1. 打开"系统偏好设置" > "用户与群组"
        2. 选择您的用户账户
        3. 点击"登录项"标签
        4. 点击"+"按钮添加PomodoroScreen应用
        
        或者：
        1. 打开"系统偏好设置" > "常规"
        2. 在"登录时打开"部分添加PomodoroScreen
        """
    }
}

// MARK: - 扩展：便利方法
extension LaunchAtLogin {
    
    /// 安全地启用开机自启动（带错误处理）
    /// - Parameter completion: 完成回调，返回是否成功和错误信息
    func enableSafely(completion: @escaping (Bool, String?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            let wasEnabled = self.isEnabled
            self.isEnabled = true
            
            DispatchQueue.main.async {
                let status = self.validateStatus()
                if status.enabled {
                    completion(true, nil)
                } else {
                    // 回滚设置
                    self.isEnabled = wasEnabled
                    completion(false, "设置失败，请尝试手动设置或检查系统权限")
                }
            }
        }
    }
    
    /// 安全地禁用开机自启动
    /// - Parameter completion: 完成回调
    func disableSafely(completion: @escaping (Bool, String?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            self.isEnabled = false
            
            DispatchQueue.main.async {
                let status = self.validateStatus()
                completion(!status.enabled, status.enabled ? "禁用失败" : nil)
            }
        }
    }
}
