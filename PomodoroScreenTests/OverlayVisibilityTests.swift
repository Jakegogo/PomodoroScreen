import XCTest
@testable import PomodoroScreen

final class OverlayVisibilityTests: XCTestCase {
    var appDelegate: AppDelegate!
    var timer: PomodoroTimer!

    override func setUp() {
        super.setUp()
        // 获取 AppDelegate
        guard let delegate = NSApplication.shared.delegate as? AppDelegate else {
            XCTFail("AppDelegate not available")
            return
        }
        appDelegate = delegate
        timer = Mirror(reflecting: appDelegate!).descendant("pomodoroTimer") as? PomodoroTimer
        XCTAssertNotNil(timer)
    }

    func testOverlayAppearsWhenRestStarts() {
        // 1) 打印关键状态
        print("[TEST] before trigger: \(appDelegate.dumpTimerStateForTesting())")

        // 2) 触发一次番茄钟完成 -> 应进入休息流程（会调用 startBreak + showOverlay）
        appDelegate.triggerPomodoroFinishForTesting()

        // 3) 等待遮罩层可见
        let exp = expectation(description: "overlay should become visible")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let visible = self.appDelegate.isOverlayVisibleForTesting()
            print("[TEST] after 1s: visible=\(visible), state=\(self.appDelegate.dumpTimerStateForTesting())")
            if visible { exp.fulfill() }
        }
        wait(for: [exp], timeout: 3.0)

        // 4) 断言
        XCTAssertTrue(appDelegate.isOverlayVisibleForTesting(), "Overlay should be visible when rest starts")
    }
}
