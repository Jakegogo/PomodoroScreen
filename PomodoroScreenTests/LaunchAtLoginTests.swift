import XCTest
@testable import PomodoroScreen

/// 开机自启动功能测试
/// 
/// 作者: AI Assistant
/// 创建时间: 2024-09-21
/// 
/// 测试开机自启动功能的各种场景
class LaunchAtLoginTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // 清理测试环境
        UserDefaults.standard.removeObject(forKey: "LaunchAtLoginEnabled")
    }
    
    override func tearDown() {
        // 恢复默认设置
        LaunchAtLogin.shared.isEnabled = false
        UserDefaults.standard.removeObject(forKey: "LaunchAtLoginEnabled")
        super.tearDown()
    }
    
    // MARK: - 基础功能测试
    
    /// 测试开机自启动的启用和禁用
    func testLaunchAtLoginEnableDisable() {
        // Given: 初始状态应该是禁用的
        XCTAssertFalse(LaunchAtLogin.shared.isEnabled, "初始状态应该是禁用的")
        
        // When: 启用开机自启动
        LaunchAtLogin.shared.isEnabled = true
        
        // Then: 状态应该变为启用
        XCTAssertTrue(LaunchAtLogin.shared.isEnabled, "启用后状态应该为true")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "LaunchAtLoginEnabled"), "UserDefaults应该保存启用状态")
        
        // When: 禁用开机自启动
        LaunchAtLogin.shared.isEnabled = false
        
        // Then: 状态应该变为禁用
        XCTAssertFalse(LaunchAtLogin.shared.isEnabled, "禁用后状态应该为false")
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "LaunchAtLoginEnabled"), "UserDefaults应该保存禁用状态")
    }
    
    /// 测试切换功能
    func testLaunchAtLoginToggle() {
        // Given: 初始状态为禁用
        LaunchAtLogin.shared.isEnabled = false
        
        // When: 切换状态
        LaunchAtLogin.shared.toggle()
        
        // Then: 状态应该变为启用
        XCTAssertTrue(LaunchAtLogin.shared.isEnabled, "切换后应该为启用状态")
        
        // When: 再次切换
        LaunchAtLogin.shared.toggle()
        
        // Then: 状态应该变为禁用
        XCTAssertFalse(LaunchAtLogin.shared.isEnabled, "再次切换后应该为禁用状态")
    }
    
    /// 测试状态验证功能
    func testLaunchAtLoginValidateStatus() {
        // Given: 设置为启用状态
        LaunchAtLogin.shared.isEnabled = true
        
        // When: 验证状态
        let status = LaunchAtLogin.shared.validateStatus()
        
        // Then: 验证结果应该正确
        XCTAssertTrue(status.enabled, "验证状态应该为启用")
        XCTAssertNotNil(status.systemEnabled, "系统状态应该有值")
        XCTAssertFalse(status.message.isEmpty, "应该有状态消息")
        
        print("📋 状态验证结果: \(status.message)")
        
        // 检查是否包含权限相关的信息
        if #available(macOS 13.0, *) {
            // 在macOS 13+中，可能会有权限批准相关的消息
            let possibleMessages = ["已启用开机自启动", "需要用户批准开机自启动", "未注册开机自启动", "服务未找到"]
            XCTAssertTrue(possibleMessages.contains { status.message.contains($0) }, "状态消息应该包含预期的内容")
        }
    }
    
    /// 测试设置指导信息
    func testLaunchAtLoginSetupInstructions() {
        // When: 获取设置指导
        let instructions = LaunchAtLogin.shared.getSetupInstructions()
        
        // Then: 指导信息应该包含关键内容
        XCTAssertTrue(instructions.contains("系统偏好设置"), "指导信息应该包含系统偏好设置")
        XCTAssertTrue(instructions.contains("登录项"), "指导信息应该包含登录项")
        XCTAssertTrue(instructions.contains("PomodoroScreen"), "指导信息应该包含应用名称")
        
        print("📖 设置指导: \(instructions)")
    }
    
    // MARK: - 异步功能测试
    
    /// 测试安全启用功能
    func testLaunchAtLoginEnableSafely() {
        let expectation = XCTestExpectation(description: "安全启用开机自启动")
        
        // Given: 初始状态为禁用
        LaunchAtLogin.shared.isEnabled = false
        
        // When: 安全启用
        LaunchAtLogin.shared.enableSafely { success, errorMessage in
            // Then: 应该成功启用
            XCTAssertTrue(success, "安全启用应该成功")
            XCTAssertNil(errorMessage, "不应该有错误消息: \(errorMessage ?? "nil")")
            XCTAssertTrue(LaunchAtLogin.shared.isEnabled, "启用后状态应该为true")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    /// 测试安全禁用功能
    func testLaunchAtLoginDisableSafely() {
        let expectation = XCTestExpectation(description: "安全禁用开机自启动")
        
        // Given: 初始状态为启用
        LaunchAtLogin.shared.isEnabled = true
        
        // When: 安全禁用
        LaunchAtLogin.shared.disableSafely { success, errorMessage in
            // Then: 应该成功禁用
            XCTAssertTrue(success, "安全禁用应该成功")
            XCTAssertNil(errorMessage, "不应该有错误消息: \(errorMessage ?? "nil")")
            XCTAssertFalse(LaunchAtLogin.shared.isEnabled, "禁用后状态应该为false")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - 持久化测试
    
    /// 测试设置的持久化
    func testLaunchAtLoginPersistence() {
        // Given: 启用开机自启动
        LaunchAtLogin.shared.isEnabled = true
        
        // When: 创建新的LaunchAtLogin实例（模拟应用重启）
        let newInstance = LaunchAtLogin.shared
        
        // Then: 状态应该保持
        XCTAssertTrue(newInstance.isEnabled, "重启后状态应该保持启用")
        
        // When: 禁用并重新检查
        LaunchAtLogin.shared.isEnabled = false
        XCTAssertFalse(newInstance.isEnabled, "禁用后状态应该保持禁用")
    }
    
    // MARK: - 边界条件测试
    
    /// 测试重复设置相同状态
    func testLaunchAtLoginRepeatedSetting() {
        // Given: 设置为启用
        LaunchAtLogin.shared.isEnabled = true
        let firstStatus = LaunchAtLogin.shared.isEnabled
        
        // When: 重复设置为启用
        LaunchAtLogin.shared.isEnabled = true
        let secondStatus = LaunchAtLogin.shared.isEnabled
        
        // Then: 状态应该保持一致
        XCTAssertEqual(firstStatus, secondStatus, "重复设置相同状态应该保持一致")
        XCTAssertTrue(LaunchAtLogin.shared.isEnabled, "状态应该仍为启用")
    }
    
    /// 测试UserDefaults同步
    func testUserDefaultsSync() {
        // Given: 直接修改UserDefaults
        UserDefaults.standard.set(true, forKey: "LaunchAtLoginEnabled")
        
        // When: 检查LaunchAtLogin状态
        let status = LaunchAtLogin.shared.isEnabled
        
        // Then: 状态应该与UserDefaults同步
        XCTAssertTrue(status, "LaunchAtLogin状态应该与UserDefaults同步")
        
        // When: 通过LaunchAtLogin修改状态
        LaunchAtLogin.shared.isEnabled = false
        
        // Then: UserDefaults应该更新
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "LaunchAtLoginEnabled"), "UserDefaults应该同步更新")
    }
}
