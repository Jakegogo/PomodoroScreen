import XCTest
@testable import PomodoroScreen

final class IconSnapshotTests: XCTestCase {
    func testGenerateAndAttachStatusBarIcons() throws {
        _ = PomodoroTimer() // 保持环境一致（如字体/上下文），未直接使用
        let iconGen = ClockIconGenerator()

        // Running icon
        let runningIcon = iconGen.generateClockIcon(
            progress: 0.25,
            totalTime: 25 * 60,
            remainingTime: 25 * 60 * 0.75,
            isPaused: false,
            isRest: false
        )
        attach(image: runningIcon, named: "icon_running.png")

        // Paused icon
        let pausedIcon = iconGen.generateClockIcon(
            progress: 0.5,
            totalTime: 25 * 60,
            remainingTime: 25 * 60 * 0.5,
            isPaused: true,
            isRest: false
        )
        attach(image: pausedIcon, named: "icon_paused.png")

        // Rest (hot cup) icon with remaining minutes
        let restRemaining: TimeInterval = 3 * 60 // 3 minutes
        let restIcon = iconGen.generateClockIcon(
            progress: 0.2,
            totalTime: 3 * 60,
            remainingTime: restRemaining,
            isPaused: false,
            isRest: true
        )
        attach(image: restIcon, named: "icon_rest_hotcup.png")
    }

    // MARK: - Helpers
    private func attach(image: NSImage, named: String) {
        // 1) 将图像作为测试附件显示在测试报告中（Xcode可直接预览）
        let attachment = XCTAttachment(image: image)
        attachment.lifetime = .keepAlways
        attachment.name = named
        add(attachment)

        // 2) 另存PNG到临时目录，便于手动查看
        if let data = pngData(from: image) {
            let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(named)
            try? data.write(to: url)
            print("📸 icon saved: \(url.path)")
        }
    }

    private func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else {
            return nil
        }
        return data
    }
}


