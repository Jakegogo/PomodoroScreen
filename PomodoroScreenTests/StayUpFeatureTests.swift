import XCTest
@testable import PomodoroScreen

/// 熬夜功能测试用例
/// 
/// 作者: AI Assistant
/// 创建时间: 2024-09-21
/// 
/// 测试熬夜限制功能的各种场景，包括时间检测、遮罩层显示、设置保存等
class StayUpFeatureTests: XCTestCase {
    
    var pomodoroTimer: PomodoroTimer!
    
    override func setUp() {
        super.setUp()
        pomodoroTimer = PomodoroTimer()
    }
    
    override func tearDown() {
        pomodoroTimer = nil
        super.tearDown()
    }
    
    // MARK: - 熬夜时间检测测试
    
    /// 测试熬夜时间检测 - 21:00-23:59范围
    func testStayUpTimeDetection_EveningHours() {
        // Given: 设置熬夜限制为22:30
        pomodoroTimer.updateStayUpSettings(enabled: true, hour: 22, minute: 30)
        
        // When & Then: 测试不同时间点
        // 注意：由于无法直接修改系统时间，这里主要测试设置是否正确保存
        XCTAssertTrue(pomodoroTimer.stayUpLimitEnabled)
        XCTAssertEqual(pomodoroTimer.stayUpLimitHour, 22)
        XCTAssertEqual(pomodoroTimer.stayUpLimitMinute, 30)
    }
    
    /// 测试熬夜时间检测 - 跨日期范围（00:00-01:00）
    func testStayUpTimeDetection_MidnightHours() {
        // Given: 设置熬夜限制为00:30（次日）
        pomodoroTimer.updateStayUpSettings(enabled: true, hour: 0, minute: 30)
        
        // When & Then: 验证设置
        XCTAssertTrue(pomodoroTimer.stayUpLimitEnabled)
        XCTAssertEqual(pomodoroTimer.stayUpLimitHour, 0)
        XCTAssertEqual(pomodoroTimer.stayUpLimitMinute, 30)
    }
    
    /// 测试禁用熬夜限制
    func testStayUpTimeDetection_Disabled() {
        // Given: 禁用熬夜限制
        pomodoroTimer.updateStayUpSettings(enabled: false, hour: 23, minute: 0)
        
        // When & Then: 验证设置
        XCTAssertFalse(pomodoroTimer.stayUpLimitEnabled)
    }
    
    // MARK: - 遮罩层行为测试
    
    /// 测试熬夜时不显示取消按钮
    func testOverlayBehavior_StayUpTime_NoCancelButton() {
        // Given: 启用熬夜限制并设置为熬夜状态
        pomodoroTimer.updateStayUpSettings(enabled: true, hour: 23, minute: 0)
        pomodoroTimer.isStayUpTime = true
        
        // When: 检查是否应该显示取消按钮
        let shouldShowButton = pomodoroTimer.shouldShowCancelRestButton
        
        // Then: 熬夜时不应该显示取消按钮
        XCTAssertFalse(shouldShowButton, "熬夜时间不应该显示取消休息按钮")
    }
    
    /// 测试非熬夜时正常显示取消按钮
    func testOverlayBehavior_NormalTime_ShowCancelButton() {
        // Given: 启用熬夜限制但不在熬夜时间
        pomodoroTimer.updateStayUpSettings(enabled: true, hour: 23, minute: 0)
        pomodoroTimer.isStayUpTime = false
        
        // When: 检查是否应该显示取消按钮
        let shouldShowButton = pomodoroTimer.shouldShowCancelRestButton
        
        // Then: 非熬夜时应该显示取消按钮（根据其他设置）
        XCTAssertTrue(shouldShowButton, "非熬夜时间应该根据设置显示取消休息按钮")
    }
    
    // MARK: - 计时器集成测试
    
    /// 测试启动计时器时的熬夜检测
    func testTimerStart_WithStayUpEnabled() {
        // Given: 启用熬夜限制
        pomodoroTimer.updateStayUpSettings(enabled: true, hour: 23, minute: 0)
        
        // When: 启动计时器
        pomodoroTimer.start()
        
        // Then: 计时器应该正常启动（如果不在熬夜时间）
        // 注意：由于无法模拟具体时间，这里主要验证方法调用不会崩溃
        XCTAssertNoThrow(pomodoroTimer.start())
    }
    
    /// 测试熬夜设置更新
    func testStayUpSettingsUpdate() {
        // Given: 初始状态
        XCTAssertFalse(pomodoroTimer.stayUpLimitEnabled)
        
        // When: 更新熬夜设置
        pomodoroTimer.updateStayUpSettings(enabled: true, hour: 22, minute: 45)
        
        // Then: 设置应该被正确更新
        XCTAssertTrue(pomodoroTimer.stayUpLimitEnabled)
        XCTAssertEqual(pomodoroTimer.stayUpLimitHour, 22)
        XCTAssertEqual(pomodoroTimer.stayUpLimitMinute, 45)
    }
    
    // MARK: - 边界条件测试
    
    /// 测试边界时间设置
    func testBoundaryTimeSettings() {
        // Test 21:00 (最早时间)
        pomodoroTimer.updateStayUpSettings(enabled: true, hour: 21, minute: 0)
        XCTAssertEqual(pomodoroTimer.stayUpLimitHour, 21)
        XCTAssertEqual(pomodoroTimer.stayUpLimitMinute, 0)
        
        // Test 01:00 (最晚时间)
        pomodoroTimer.updateStayUpSettings(enabled: true, hour: 1, minute: 0)
        XCTAssertEqual(pomodoroTimer.stayUpLimitHour, 1)
        XCTAssertEqual(pomodoroTimer.stayUpLimitMinute, 0)
        
        // Test 分钟边界
        pomodoroTimer.updateStayUpSettings(enabled: true, hour: 23, minute: 45)
        XCTAssertEqual(pomodoroTimer.stayUpLimitMinute, 45)
    }
    
    /// 测试多次设置更新
    func testMultipleSettingsUpdates() {
        // 第一次设置
        pomodoroTimer.updateStayUpSettings(enabled: true, hour: 22, minute: 0)
        XCTAssertTrue(pomodoroTimer.stayUpLimitEnabled)
        XCTAssertEqual(pomodoroTimer.stayUpLimitHour, 22)
        
        // 第二次设置
        pomodoroTimer.updateStayUpSettings(enabled: false, hour: 23, minute: 30)
        XCTAssertFalse(pomodoroTimer.stayUpLimitEnabled)
        XCTAssertEqual(pomodoroTimer.stayUpLimitHour, 23)
        XCTAssertEqual(pomodoroTimer.stayUpLimitMinute, 30)
        
        // 第三次设置
        pomodoroTimer.updateStayUpSettings(enabled: true, hour: 0, minute: 15)
        XCTAssertTrue(pomodoroTimer.stayUpLimitEnabled)
        XCTAssertEqual(pomodoroTimer.stayUpLimitHour, 0)
        XCTAssertEqual(pomodoroTimer.stayUpLimitMinute, 15)
    }
}
