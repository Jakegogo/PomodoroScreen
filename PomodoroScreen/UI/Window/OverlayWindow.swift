import Cocoa
import AVFoundation
import IOKit.ps

class OverlayWindow: NSWindow {
    
    // MARK: - Properties
    
    private var overlayView: OverlayView!
    private var dismissTimer: Timer?
    private var timer: PomodoroTimer? // 添加timer引用
    fileprivate var isPreviewMode: Bool = false // 预览模式标志
    
    // 背景文件相关属性
    private var backgroundFiles: [BackgroundFile] = []
    private var currentBackgroundIndex: Int = 0
    private var backgroundRotationTimer: Timer?
    
    // 视频播放相关属性
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var videoContainerView: NSView?
    private var currentPlaybackRate: Double = 1.0 // 当前播放速率
    
    // 图片背景相关属性
    private var imageView: NSImageView?
    
    // 设备性能检测器
    private let performanceDetector = DevicePerformanceDetector.shared
    private var deviceInfo: DevicePerformanceDetector.DeviceInfo?

    // 统一关闭原因
    fileprivate enum DismissReason { case user, autoOverlay, preview, shutdownConfirmed }
    
    // MARK: - Initialization
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        setupWindow()
    }
    
    convenience init(timer: PomodoroTimer) {
        // 获取主屏幕尺寸
        let screenRect = NSScreen.main?.frame ?? NSRect.zero
        
        self.init(
            contentRect: screenRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // 设置timer引用
        self.timer = timer
        self.isPreviewMode = false
        
        // 获取背景文件设置并切换到下一个背景
        self.backgroundFiles = timer.getBackgroundFiles()
        self.currentBackgroundIndex = timer.getNextBackgroundIndex()
        
        // 创建遮罩视图，传入计时器引用
        overlayView = OverlayView(frame: screenRect, timer: timer)
    }
    
    // 预览模式初始化方法
    convenience init(previewFiles: [BackgroundFile], selectedIndex: Int = 0) {
        // 获取主屏幕尺寸
        let screenRect = NSScreen.main?.frame ?? NSRect.zero
        
        self.init(
            contentRect: screenRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // 设置预览模式
        self.timer = nil
        self.isPreviewMode = true
        self.backgroundFiles = previewFiles
        self.currentBackgroundIndex = selectedIndex >= 0 && selectedIndex < previewFiles.count ? selectedIndex : 0
        
        // 创建预览遮罩视图（不传入计时器）
        overlayView = OverlayView(frame: screenRect, timer: nil, isPreviewMode: true)
    }
    
    // MARK: - Public Methods
    
    func showOverlay() {
        setupOverlayProperties()
        setupOverlayView()
        setupVideoPlayer()
        
        // 设置初始透明度为0（完全透明）
        alphaValue = 0.0
        
        makeKeyAndOrderFront(nil)
        
        // 确保窗口始终在最前面
        level = .screenSaver
        
        // 禁用所有窗口交互
        ignoresMouseEvents = false
        
        // 获取焦点并保持
        becomeKey()
        makeMain()
        
        // 防止窗口被最小化或关闭
        setupWindowBehavior()
        
        // 添加淡入动画效果
        animateIn()
        
        // 设置3分钟后自动隐藏
        startDismissTimer()
        
        // 如果是预览模式且有多个文件，启动轮播
        if isPreviewMode && backgroundFiles.count > 1 {
            startBackgroundRotation()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupWindow() {
        // 基本窗口设置
        isOpaque = false
        backgroundColor = NSColor.clear
        hasShadow = false
        isMovable = false
        isRestorable = false
        
        // 检测设备性能和主题模式
        deviceInfo = performanceDetector.detectDeviceInfo()
    }
    
    private func setupOverlayProperties() {
        // 设置窗口层级为最高
        level = .screenSaver
        
        // 覆盖所有桌面空间
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        
        // 禁用标准窗口行为
        styleMask = [.borderless]
        
        // 只有在窗口尺寸为零时才设置为主屏幕尺寸
        // 这样可以避免覆盖多屏幕管理器设置的特定屏幕尺寸
        if frame.size.width == 0 || frame.size.height == 0 {
            if let screen = NSScreen.main {
                setFrame(screen.frame, display: true)
            }
        }
    }
    
    private func setupOverlayView() {
        // 如果overlayView还没有创建，创建一个默认的
        if overlayView == nil {
            overlayView = OverlayView(frame: frame, timer: nil)
        }
        contentView = overlayView
        
        // 设置取消按钮的点击事件处理
        overlayView.onDismiss = { [weak self] in
            if self?.isPreviewMode == true {
                self?.dismissOverlay(reason: .preview)
            } else {
                self?.dismissOverlay(reason: .user)
            }
        }
    }
    
    private func setupWindowBehavior() {
        // 禁用窗口关闭按钮
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        
        // 监听应用程序事件，防止切换
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillResignActive),
            name: NSApplication.willResignActiveNotification,
            object: nil
        )
    }
    
    @objc private func applicationDidBecomeActive() {
        // 确保遮罩层始终在最前面
        makeKeyAndOrderFront(nil)
        level = .screenSaver
    }
    
    @objc private func applicationWillResignActive() {
        // 阻止应用程序失去焦点
        NSApplication.shared.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
    }
    
    private func setupVideoPlayer() {
        // 创建背景容器视图
        videoContainerView = NSView(frame: frame)
        videoContainerView?.wantsLayer = true
        videoContainerView?.layer?.masksToBounds = true // 剪裁超出边界的内容
        
        // 添加到内容视图的最底层
        if let containerView = videoContainerView {
            contentView?.addSubview(containerView, positioned: .below, relativeTo: overlayView)
            
            // 设置约束使其填充整个窗口
            containerView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                containerView.topAnchor.constraint(equalTo: contentView!.topAnchor),
                containerView.leadingAnchor.constraint(equalTo: contentView!.leadingAnchor),
                containerView.trailingAnchor.constraint(equalTo: contentView!.trailingAnchor),
                containerView.bottomAnchor.constraint(equalTo: contentView!.bottomAnchor)
            ])
        }
        
        // 设置背景
        setupBackground()
    }
    
    private func setupBackground() {
        if backgroundFiles.isEmpty {
            // 如果没有背景文件，使用智能默认背景策略
            if let mediaURL = findDefaultBackgroundFile() {
                setupDefaultMedia(with: mediaURL)
            }
        } else {
            // 使用配置的背景文件
            setupBackgroundFromFiles()
        }
    }
    
    private func setupDefaultMedia(with url: URL) {
        let fileExtension = url.pathExtension.lowercased()
        
        switch fileExtension {
        case "mp4", "mov", "avi", "mkv":
            // 视频文件
            setupPlayer(with: url)
        case "png", "jpg", "jpeg", "gif", "bmp", "tiff":
            // 图片文件
            setupImageBackground(with: url)
        default:
            print("❌ 不支持的媒体文件格式: \(fileExtension)")
            // 尝试作为视频处理
            setupPlayer(with: url)
        }
    }
    
    private func setupBackgroundFromFiles() {
        guard !backgroundFiles.isEmpty else { return }
        
        // 确保索引在有效范围内
        if currentBackgroundIndex < 0 || currentBackgroundIndex >= backgroundFiles.count {
            print("❌ 背景文件索引越界: \(currentBackgroundIndex), 文件数量: \(backgroundFiles.count)")
            currentBackgroundIndex = 0 // 重置为第一个文件
            if backgroundFiles.isEmpty { return }
        }
        
        let currentFile = backgroundFiles[currentBackgroundIndex]
        let fileURL = URL(fileURLWithPath: currentFile.path)
        
        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: currentFile.path) else {
            print("❌ 背景文件不存在: \(currentFile.path)")
            // 尝试下一个文件
            moveToNextBackground()
            return
        }
        
        switch currentFile.type {
        case .image:
            setupImageBackground(with: fileURL)
        case .video:
            setupPlayer(with: fileURL, playbackRate: currentFile.playbackRate)
        }
    }
    
    private func setupImageBackground(with url: URL) {
        // 清理之前的视频播放器
        cleanupVideoPlayer()
        
        // 创建或更新图片视图
        if imageView == nil {
            imageView = NSImageView()
            imageView?.imageScaling = .scaleNone // 不自动缩放，我们手动控制
            imageView?.wantsLayer = true
            imageView?.layer?.zPosition = -1000
            
            if let containerView = videoContainerView {
                containerView.addSubview(imageView!)
                
                // 设置约束使其填充整个容器
                imageView!.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    imageView!.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                    imageView!.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
                ])
            }
        }
        
        // 加载图片并计算填充尺寸
        if let originalImage = NSImage(contentsOf: url) {
            let screenSize = frame.size
            let imageSize = originalImage.size
            
            // 计算缩放比例，使图片能够填充整个屏幕（类似 resizeAspectFill）
            let scaleX = screenSize.width / imageSize.width
            let scaleY = screenSize.height / imageSize.height
            let scale = max(scaleX, scaleY) // 使用较大的缩放比例确保填充
            
            let scaledWidth = imageSize.width * scale
            let scaledHeight = imageSize.height * scale
            
            // 创建缩放后的图片
            let scaledImage = NSImage(size: NSSize(width: scaledWidth, height: scaledHeight))
            scaledImage.lockFocus()
            originalImage.draw(in: NSRect(origin: .zero, size: NSSize(width: scaledWidth, height: scaledHeight)),
                             from: NSRect(origin: .zero, size: imageSize),
                             operation: .copy,
                             fraction: 1.0)
            scaledImage.unlockFocus()
            
            // 设置图片和尺寸约束
            imageView?.image = scaledImage
            
            // 更新尺寸约束
            if let imageView = imageView {
                // 移除之前的尺寸约束
                imageView.removeConstraints(imageView.constraints.filter { 
                    $0.firstAttribute == .width || $0.firstAttribute == .height 
                })
                
                // 添加新的尺寸约束
                NSLayoutConstraint.activate([
                    imageView.widthAnchor.constraint(equalToConstant: scaledWidth),
                    imageView.heightAnchor.constraint(equalToConstant: scaledHeight)
                ])
            }
            
        } else {
            // 尝试下一个文件
            moveToNextBackground()
        }
    }
    
    private func moveToNextBackground() {
        guard backgroundFiles.count > 1 else { return }
        
        currentBackgroundIndex = (currentBackgroundIndex + 1) % backgroundFiles.count
        setupBackgroundFromFiles()
    }
    
    private func findVideoFile() -> URL? {
        // 使用智能默认背景策略
        return findDefaultBackgroundFile()
    }
    
    
    // MARK: - Smart Default Background Strategy
    
    private func findDefaultBackgroundFile() -> URL? {
        // 获取设备信息（如果还没有检测过）
        let info = deviceInfo ?? performanceDetector.detectDeviceInfo()
        
        // 根据性能选择媒体类型
        let preferVideo = info.isHighPerformance
        let themePrefix = info.isDarkMode ? "dark" : "light"
        
        if preferVideo {
            // 高性能设备优先尝试视频
            if let videoURL = findThemeVideo(theme: themePrefix) {
                return videoURL
            }
            
            // 视频不可用时降级到图片
            if let imageURL = findThemeImage(theme: themePrefix) {
                return imageURL
            }
        } else {
            // 低性能设备优先尝试图片
            if let imageURL = findThemeImage(theme: themePrefix) {
                return imageURL
            }
            
            // 图片不可用时降级到视频
            if let videoURL = findThemeVideo(theme: themePrefix) {
                return videoURL
            }
        }
        
        // 最后的备用方案：查找任何可用的默认文件
        return findFallbackMedia()
    }
    
    private func findThemeVideo(theme: String) -> URL? {
        let videoName = "rest_video_\(theme)"
        return Bundle.main.url(forResource: videoName, withExtension: "mp4")
    }
    
    private func findThemeImage(theme: String) -> URL? {
        let imageName = "rest_image_\(theme)"
        
        // 尝试不同的图片格式
        let extensions = ["png", "jpg", "jpeg"]
        for ext in extensions {
            if let imageURL = Bundle.main.url(forResource: imageName, withExtension: ext) {
                return imageURL
            }
        }
        return nil
    }
    
    private func findFallbackMedia() -> URL? {
        // 备用视频文件
        let fallbackVideos = ["rest_video", "icon_video"]
        for videoName in fallbackVideos {
            if let videoURL = Bundle.main.url(forResource: videoName, withExtension: "mp4") {
                return videoURL
            }
        }
        
        // 备用图片文件（任何可用的rest_image文件）
        let imageExtensions = ["png", "jpg", "jpeg"]
        for ext in imageExtensions {
            if let imageURL = Bundle.main.url(forResource: "rest_image_light", withExtension: ext) ??
                              Bundle.main.url(forResource: "rest_image_dark", withExtension: ext) {
                return imageURL
            }
        }
        
        return nil
    }
    
    private func setupPlayer(with url: URL, playbackRate: Double = 1.0) {
        // 存储当前播放速率
        currentPlaybackRate = playbackRate
        
        // 创建播放器
        player = AVPlayer(url: url)
        
        // 创建播放器图层
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.videoGravity = .resizeAspectFill // 填充屏幕，保持宽高比
        
        // 添加到视频容器视图
        if let layer = playerLayer, let containerView = videoContainerView {
            containerView.layer?.addSublayer(layer)
            // 确保视频图层在底层
            layer.zPosition = -1000
            updateVideoLayerFrame()
        }
        
        // 设置循环播放
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem
        )
        
        // 开始播放并设置播放速率
        player?.play()
        
        // 等待播放器准备好后设置播放速率
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.applyPlaybackRate()
        }
    }
    
    private func updateVideoLayerFrame() {
        if let layer = playerLayer, let containerView = videoContainerView {
            layer.frame = containerView.bounds
        }
    }
    
    @objc private func playerDidFinishPlaying() {
        // 重新开始播放（循环）
        player?.seek(to: .zero)
        player?.play()
        
        // 重新应用播放速率（延迟一点确保播放器准备好）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.applyPlaybackRate()
        }
    }
    
    private func applyPlaybackRate() {
        guard let player = player else { return }
        player.rate = Float(currentPlaybackRate)
        print("✅ 设置视频播放速率: \(currentPlaybackRate)x")
    }
    
    private func animateIn() {
        // 淡入动画：从透明到不透明，持续1.5秒
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 1.5
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().alphaValue = 1.0
        }
    }
    
    private func startDismissTimer() {
        // 清除之前的定时器
        dismissTimer?.invalidate()
        
        // 如果是强制睡眠状态，不设置自动关闭定时器
        if let timer = self.timer, timer.isStayUpTime {
            print("🌙 强制睡眠期间，禁用自动关闭定时器")
            return
        }

        // 这里使用 PomodoroTimer 的当前剩余时间作为自动关闭时长：
        // - 休息开始时：remainingTime = 本次休息总时长（含累加）
        // - 因此遮罩层应在休息结束时自动关闭
        let autoDismissInterval = max(1.0, timer?.getRemainingTime() ?? 180.0)
        dismissTimer = Timer.scheduledTimer(withTimeInterval: autoDismissInterval, repeats: false) { [weak self] _ in
            self?.dismissOverlay(reason: .autoOverlay)
        }
    }
    
    fileprivate func dismissOverlay(reason: DismissReason) {
        // 如果是强制睡眠状态，默认阻止关闭；但“已确认关机”场景必须立刻隐藏以避免界面阻塞
        if !isPreviewMode, let timer = self.timer, timer.isStayUpTime, reason != .shutdownConfirmed {
            print("🚫 强制睡眠期间，无法关闭遮罩层 (reason=\(reason))")
            return
        }
        
        // 清除定时器
        dismissTimer?.invalidate()
        dismissTimer = nil
        backgroundRotationTimer?.invalidate()
        backgroundRotationTimer = nil
        
        // 停止并清理背景
        cleanupBackground()
        
        // 只有在非预览模式下才通知计时器
        if !isPreviewMode, let timer = self.timer, timer.isInRestPeriod {
            switch reason {
            case .user:
                timer.cancelBreak(source: "user")
            case .autoOverlay:
                // 修复：遮罩层自动关闭仅用于隐藏 UI，不应驱动休息结束。
                // 休息结束应由 PomodoroTimer 自身倒计时到 0 后触发（避免重复/提前结束）。
                break
            case .shutdownConfirmed:
                // 关机确认：不去动计时器，立即隐藏遮罩以避免阻塞
                break
            case .preview:
                break
            }
        }
        
        // 添加淡出动画效果
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().alphaValue = 0.0
        }) { [weak self] in
            // 动画完成后隐藏窗口
            if let strongSelf = self {
                NotificationCenter.default.removeObserver(strongSelf)
                strongSelf.orderOut(nil)
            }
            
            // 重置应用程序状态
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
    
    private func startBackgroundRotation() {
        backgroundRotationTimer?.invalidate()
        backgroundRotationTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.switchToNextBackground()
        }
    }
    
    private func switchToNextBackground() {
        guard backgroundFiles.count > 1 else { return }
        
        currentBackgroundIndex = (currentBackgroundIndex + 1) % backgroundFiles.count
        setupBackgroundFromFiles()
    }
    
    private func cleanupVideoPlayer() {
        // 停止播放
        player?.pause()
        
        // 移除观察者
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem)
        
        // 移除播放器图层
        playerLayer?.removeFromSuperlayer()
        
        // 清空播放器引用
        player = nil
        playerLayer = nil
    }
    
    private func cleanupBackground() {
        // 清理视频播放器
        cleanupVideoPlayer()
        
        // 清理图片视图
        imageView?.removeFromSuperview()
        imageView = nil
        
        // 清理容器视图
        videoContainerView?.removeFromSuperview()
        videoContainerView = nil
    }
    
    // MARK: - Override Methods
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    override func close() {
        // 阻止窗口被关闭
        // 不调用 super.close()
    }
    
    override func miniaturize(_ sender: Any?) {
        // 阻止窗口被最小化
        // 不调用 super.miniaturize()
    }
}

// MARK: - OverlayView

// MARK: - Button Configuration

struct OverlayButtonConfig {
    let title: String
    let width: CGFloat
    let height: CGFloat
    let backgroundColor: NSColor
    let borderColor: NSColor
    let borderWidth: CGFloat
    let cornerRadius: CGFloat
    let font: NSFont
    let fadeAlpha: CGFloat
    let hoverAlpha: CGFloat
    let action: Selector
    let keyEquivalent: String?
    let hasShadow: Bool
    let shadowColor: NSColor?
    let shadowOffset: NSSize?
    let shadowRadius: CGFloat?
    let shadowOpacity: Float?
    
    init(title: String, 
         width: CGFloat, 
         height: CGFloat,
         backgroundColor: NSColor = NSColor.clear,
         borderColor: NSColor = NSColor.white,
         borderWidth: CGFloat = 1.5,
         cornerRadius: CGFloat = 6,
         font: NSFont = NSFont.systemFont(ofSize: 14, weight: .regular),
         fadeAlpha: CGFloat = 0.3,
         hoverAlpha: CGFloat = 1.0,
         action: Selector,
         keyEquivalent: String? = nil,
         hasShadow: Bool = false,
         shadowColor: NSColor? = nil,
         shadowOffset: NSSize? = nil,
         shadowRadius: CGFloat? = nil,
         shadowOpacity: Float? = nil) {
        
        self.title = title
        self.width = width
        self.height = height
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.cornerRadius = cornerRadius
        self.font = font
        self.fadeAlpha = fadeAlpha
        self.hoverAlpha = hoverAlpha
        self.action = action
        self.keyEquivalent = keyEquivalent
        self.hasShadow = hasShadow
        self.shadowColor = shadowColor
        self.shadowOffset = shadowOffset
        self.shadowRadius = shadowRadius
        self.shadowOpacity = shadowOpacity
    }
}

class OverlayView: NSView {
    
    var onDismiss: (() -> Void)?
    private var cancelButton: NSButton!
    private var shutdownButton: NSButton!  // 关机按钮
    private var messageLabel: NSTextField!
    private var timer: PomodoroTimer?
    private var isPreviewMode: Bool = false
    private var shutdownConfirmationWindow: ShutdownConfirmationWindow?  // 关机确认对话框
    private var countdownTimer: Timer?  // 倒计时定时器
    private var isHoveringCancelButton: Bool = false  // 是否鼠标悬停在取消按钮上
    
    // MARK: - Test Detection
    private func isRunningUnitTests() -> Bool {
        return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    
    // MARK: - Button Configurations
    
    private var cancelButtonConfig: OverlayButtonConfig {
        // 默认显示倒计时，而不是"取消休息"
        let title = getCountdownString()
        // 使用 SF Pro Rounded Heavy 字体 - 友好、圆润、不抢眼
        let customFont = loadCustomFont(name: "SF-Pro-Rounded-Heavy", size: 36) ?? NSFont.systemFont(ofSize: 36, weight: .regular)
        return OverlayButtonConfig(
            title: title,
            width: 120,  // 增加宽度以适应36pt大字体
            height: 36,   // 增加高度以适应36pt大字体
            borderColor: NSColor.clear,  // 默认边框透明
            font: customFont,
            fadeAlpha: 0.2,  // 10秒后淡化到低透明度（0.2）
            action: #selector(cancelButtonClicked)
        )
    }
    
    // 获取倒计时字符串
    private func getCountdownString() -> String {
        guard let timer = timer else { return "0:00" }
        let remainingTime = timer.getRemainingTime()
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        // 分钟不补0，秒数补0（例如：5:53 而不是 05:53）
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // 加载自定义字体（参考 HealthRingsView 的实现）
    private func loadCustomFont(name: String, size: CGFloat) -> NSFont? {
        // 1. 尝试直接通过字体名称加载（可能已经注册过）
        if let font = NSFont(name: name, size: size) {
            print("✅ 直接加载自定义字体成功: \(name)")
            return font
        }
        
        // 2. 如果直接加载失败，尝试从 Bundle 加载字体文件
        guard let fontURL = Bundle.main.url(forResource: name, withExtension: "ttf") else {
            print("⚠️ 字体文件未找到: \(name).ttf")
            return nil
        }
        
        guard let fontData = NSData(contentsOf: fontURL) else {
            print("⚠️ 无法读取字体文件: \(fontURL.path)")
            return nil
        }
        
        guard let provider = CGDataProvider(data: fontData) else {
            print("⚠️ 无法创建字体数据提供者")
            return nil
        }
        
        guard let cgFont = CGFont(provider) else {
            print("⚠️ 无法创建 CGFont")
            return nil
        }
        
        guard let fontName = cgFont.postScriptName else {
            print("⚠️ 无法获取字体的 PostScript 名称")
            return nil
        }
        
        // 3. 注册字体到系统
        CTFontManagerRegisterGraphicsFont(cgFont, nil)
        print("✅ 已注册字体: \(fontName)")
        
        // 4. 使用 PostScript 名称创建字体
        if let font = NSFont(name: String(fontName), size: size) {
            print("✅ 成功创建自定义字体: \(fontName)")
            return font
        }
        
        print("⚠️ 字体注册成功但创建失败")
        return nil
    }
    
    private var previewButtonConfig: OverlayButtonConfig {
        return OverlayButtonConfig(
            title: "关闭预览",
            width: 90,
            height: 32,
            action: #selector(previewButtonClicked),
            keyEquivalent: "\u{1b}" // ESC键
        )
    }
    
    private var shutdownButtonConfig: OverlayButtonConfig {
        return OverlayButtonConfig(
            title: "关机休息",
            width: 120,
            height: 36,
            backgroundColor: NSColor.systemRed.withAlphaComponent(0.8),
            borderWidth: 2.0,
            cornerRadius: 8,
            font: NSFont.systemFont(ofSize: 14, weight: .medium),
            fadeAlpha: 0.7,
            action: #selector(shutdownButtonClicked),
            hasShadow: true,
            shadowColor: NSColor.black,
            shadowOffset: NSSize(width: 0, height: -2),
            shadowRadius: 4,
            shadowOpacity: 0.5
        )
    }
    
    init(frame frameRect: NSRect, timer: PomodoroTimer?, isPreviewMode: Bool = false) {
        self.timer = timer
        self.isPreviewMode = isPreviewMode
        super.init(frame: frameRect)
        setupView()
    }
    
    init(frame frameRect: NSRect, timer: PomodoroTimer?) {
        self.timer = timer
        self.isPreviewMode = false
        super.init(frame: frameRect)
        setupView()
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        
        if isPreviewMode {
            // 预览模式：半透明黑色背景
            layer?.backgroundColor = NSColor.black.withAlphaComponent(0.3).cgColor
        } else {
            // 正常模式：完全透明的背景，让视频能够透过显示
            layer?.backgroundColor = NSColor.clear.cgColor
        }
        
        // 确保这个视图在最上层
        layer?.zPosition = 1000
        
        setupMessageLabel()
        
        // 根据模式决定是否显示按钮
        if isPreviewMode {
            setupButton(with: previewButtonConfig, as: &cancelButton, buttonType: "cancel")
        } else {
            // 检查是否为强制睡眠状态
            if let timer = timer, timer.isStayUpTime {
                setupButton(with: shutdownButtonConfig, as: &shutdownButton, buttonType: "shutdown")
            } else {
                // 根据设置决定是否显示取消休息按钮
                let shouldShowButton = timer?.shouldShowCancelRestButton ?? true
                if shouldShowButton {
                    setupButton(with: cancelButtonConfig, as: &cancelButton, buttonType: "cancel")
                    // 启动倒计时定时器，每秒更新按钮文字
                    startCountdownTimer()
                }
            }
        }
    }
    
    // MARK: - Countdown Timer
    
    /// 启动倒计时定时器，每秒更新按钮文字
    private func startCountdownTimer() {
        // 确保之前的定时器已停止
        stopCountdownTimer()
        
        // 创建新的定时器，每秒触发一次
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateCancelButtonTitle()
        }
    }
    
    /// 停止倒计时定时器
    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
    
    /// 更新取消按钮的标题和字体（带渐变动画）
    private func updateCancelButtonTitle() {
        guard let cancelButton = cancelButton else { return }
        
        let oldTitle = cancelButton.title
        
        // 如果鼠标悬停，显示"取消休息"并使用默认字体
        if isHoveringCancelButton {
            let newTitle = "取消休息"
            // 切换为默认字体和大小
            let newFont = NSFont.systemFont(ofSize: 14, weight: .regular)
            
            // 如果文字发生变化，使用渐变动画
            if oldTitle != newTitle {
                animateTitleChange(button: cancelButton, newTitle: newTitle, newFont: newFont)
            }
        } else {
            let newTitle = getCountdownString()
            // 切换为自定义字体和大小
            let customFont = loadCustomFont(name: "SF-Pro-Rounded-Heavy", size: 36) 
                ?? NSFont.systemFont(ofSize: 36, weight: .regular)
            
            // 如果文字发生变化，使用渐变动画
            if oldTitle != newTitle {
                animateTitleChange(button: cancelButton, newTitle: newTitle, newFont: customFont)
            }
        }
    }
    
    /// 文字渐变切换动画（交叉淡入淡出，无闪烁）
    private func animateTitleChange(button: NSButton, newTitle: String, newFont: NSFont) {
        // 使用 CATransition 实现平滑过渡，旧文字淡出的同时新文字淡入
        let transition = CATransition()
        transition.duration = 0.3
        transition.type = .fade
        transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        // 添加过渡动画到按钮的 layer
        button.layer?.add(transition, forKey: "textTransition")
        
        // 立即更改文字和字体（在动画期间平滑过渡）
        button.title = newTitle
        button.font = newFont
    }
    
    /// 清理资源
    deinit {
        stopCountdownTimer()
    }
    
    private func setupMessageLabel() {
        messageLabel = NSTextField(frame: NSRect(x: 0, y: 0, width: 800, height: 200))
        
        if isPreviewMode {
            // 预览模式显示预览标题
            messageLabel.stringValue = "背景预览"
        } else {
            // 正常模式根据是否为熬夜时间显示不同消息
            if let timer = timer, timer.isStayUpTime {
                let template = SettingsStore.overlayStayUpMessageTemplate
                messageLabel.stringValue = OverlayMessageTemplateRenderer.renderStayUpMessage(template: template)
            } else {
                // 获取当前休息时间信息并显示
                if let timer = timer {
                    let breakInfo = timer.getCurrentBreakInfo()
                    let breakType = breakInfo.isLongBreak ? "长休息" : "休息"
                    // 休息文案：本次休息在 PomodoroTimer 中已选定（避免多屏遮罩触发轮播多次）
                    let template = timer.currentRestOverlayMessageTemplate ?? SettingsStore.overlayRestMessageTemplate
                    messageLabel.stringValue = OverlayMessageTemplateRenderer.renderRestMessage(
                        template: template,
                        breakType: breakType,
                        breakMinutes: breakInfo.breakMinutes
                    )
                } else {
                    messageLabel.stringValue = "番茄钟时间到！\n\n休息时间"
                }
            }
        }
        messageLabel.isEditable = false
        messageLabel.isSelectable = false
        messageLabel.isBezeled = false
        messageLabel.drawsBackground = false
        messageLabel.alignment = .center
        messageLabel.font = NSFont.systemFont(ofSize: 36, weight: .bold)
        messageLabel.textColor = NSColor.white
        
        // 设置阴影效果
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.9)
        shadow.shadowOffset = NSSize(width: 3, height: -3)
        shadow.shadowBlurRadius = 8
        messageLabel.shadow = shadow
        
        // 设置多行文本
        messageLabel.maximumNumberOfLines = 0
        messageLabel.lineBreakMode = .byWordWrapping
        
        addSubview(messageLabel)
        
        // 设置约束
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            messageLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            messageLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -100),
            messageLabel.widthAnchor.constraint(equalToConstant: 800),
            messageLabel.heightAnchor.constraint(equalToConstant: 200)
        ])
        
        // 3秒后淡出文字
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.fadeOutMessageLabel()
        }
    }
    
    private func fadeOutMessageLabel() {
        guard let messageLabel = messageLabel else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 1.0 // 淡出动画持续1秒
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            messageLabel.animator().alphaValue = 0.0
        }, completionHandler: {
            // 动画完成后隐藏文字标签
            messageLabel.isHidden = true
        })
    }
    
    // MARK: - Unified Button Setup
    
    private func setupButton(with config: OverlayButtonConfig, as button: inout NSButton!, buttonType: String) {
        // 创建按钮
        let newButton = NSButton(frame: NSRect(x: 0, y: 0, width: config.width, height: config.height))
        newButton.title = config.title
        newButton.bezelStyle = .shadowlessSquare
        newButton.isBordered = false
        newButton.font = config.font
        newButton.target = self
        newButton.action = config.action
        
        // 设置键盘快捷键（如果有）
        if let keyEquivalent = config.keyEquivalent {
            newButton.keyEquivalent = keyEquivalent
        }
        
        // 设置样式
        newButton.wantsLayer = true
        newButton.layer?.backgroundColor = config.backgroundColor.cgColor
        newButton.layer?.cornerRadius = config.cornerRadius
        newButton.layer?.borderWidth = config.borderWidth
        newButton.layer?.borderColor = config.borderColor.cgColor
        newButton.contentTintColor = NSColor.white
        
        // 设置阴影（如果需要）
        if config.hasShadow {
            newButton.layer?.shadowColor = config.shadowColor?.cgColor
            newButton.layer?.shadowOffset = config.shadowOffset ?? NSSize.zero
            newButton.layer?.shadowRadius = config.shadowRadius ?? 0
            newButton.layer?.shadowOpacity = config.shadowOpacity ?? 0
        }
        
        addSubview(newButton)
        
        // 设置约束
        newButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            newButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            // 下移：将“距离底部”的边距减少 50%（原来是视图高度的 20%，现在是 10%）
            newButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -bounds.height * 0.1),
            newButton.widthAnchor.constraint(equalToConstant: config.width),
            newButton.heightAnchor.constraint(equalToConstant: config.height)
        ])
        
        // 赋值给inout参数
        button = newButton

        // 立即启用 hover（不要等淡化动画结束；否则 10 秒内 hover 看起来会“失灵”）
        enableButtonHoverEffect(for: newButton, buttonType: buttonType)
        
        // 立即开始淡化按钮（在10秒内从1.0降到0.2）
        DispatchQueue.main.async { [weak self, weak newButton] in
            guard let strongButton = newButton else { return }
            self?.fadeButton(strongButton, to: config.fadeAlpha, buttonType: buttonType)
        }
    }
    
    private func fadeButton(_ button: NSButton, to alpha: CGFloat, buttonType: String) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 10.0  // 10秒缓慢淡化
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            button.animator().alphaValue = alpha
        }, completionHandler: nil)
    }
    
    private func enableButtonHoverEffect(for button: NSButton, buttonType: String) {
        // 避免重复添加 trackingArea
        for area in button.trackingAreas {
            button.removeTrackingArea(area)
        }

        // 注意：OverlayWindow 有时不会成为 key window，使用 activeInKeyWindow 会导致 hover “偶发失灵”
        // 使用 inVisibleRect 让 trackingArea 自动跟随 bounds 更新
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: ["button": buttonType]
        )
        button.addTrackingArea(trackingArea)
    }
    
    
    
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        
        // 检查是哪个按钮的悬停事件
        if let userInfo = event.trackingArea?.userInfo as? [String: String],
           let buttonType = userInfo["button"] {
            handleButtonHover(buttonType: buttonType, isEntering: true)
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        
        // 检查是哪个按钮的离开事件
        if let userInfo = event.trackingArea?.userInfo as? [String: String],
           let buttonType = userInfo["button"] {
            handleButtonHover(buttonType: buttonType, isEntering: false)
        }
    }
    
    // MARK: - Unified Hover Effect Handler
    
    private func handleButtonHover(buttonType: String, isEntering: Bool) {
        switch buttonType {
        case "cancel":
            guard let cancelButton = cancelButton else { return }
            
            // 更新悬停状态
            isHoveringCancelButton = isEntering
            
            // 立即更新按钮文字
            updateCancelButtonTitle()
            
            // hover 时：显示白色边框 + 透明度0.7
            // 非 hover 时：隐藏边框 + 透明度0.2
            let borderColor = isEntering ? NSColor.white.cgColor : NSColor.clear.cgColor
            let targetAlpha: CGFloat = isEntering ? 0.7 : 0.2
            
            // 改变边框颜色和透明度
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                cancelButton.animator().alphaValue = targetAlpha
                cancelButton.layer?.borderColor = borderColor
            }, completionHandler: nil)
            
        case "shutdown":
            guard let shutdownButton = shutdownButton else { return }
            let targetAlpha: CGFloat = isEntering ? 1.0 : 0.7
            let backgroundColor = isEntering ? 
                NSColor.systemRed.cgColor : 
                NSColor.systemRed.withAlphaComponent(0.8).cgColor
            
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = isEntering ? 0.2 : 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                shutdownButton.animator().alphaValue = targetAlpha
                shutdownButton.layer?.backgroundColor = backgroundColor
            }, completionHandler: nil)
            
        default:
            break
        }
    }
    
    private func animateButtonAlpha(_ button: NSButton, to alpha: CGFloat, duration: TimeInterval) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            button.animator().alphaValue = alpha
        }, completionHandler: nil)
    }
    
    @objc func cancelButtonClicked() {
        if let window = self.window as? OverlayWindow {
            window.dismissOverlay(reason: window.isPreviewMode ? .preview : .user)
        }
    }
    
    @objc func previewButtonClicked() {
        if let window = self.window as? OverlayWindow {
            window.dismissOverlay(reason: .preview)
        }
    }
    
    @objc func shutdownButtonClicked() {
        print("🔴 用户点击关机按钮")
        
        // 创建并显示自定义确认对话框
        shutdownConfirmationWindow = ShutdownConfirmationWindow()
        
        // 设置回调
        shutdownConfirmationWindow?.onConfirm = { [weak self] in
            print("✅ 用户确认关机")
            // 先隐藏遮罩，避免部分应用阻止关机导致界面卡住
            if let window = self?.window as? OverlayWindow {
                window.dismissOverlay(reason: .shutdownConfirmed)
            }
            self?.triggerSystemShutdown()
            self?.shutdownConfirmationWindow = nil
        }
        
        shutdownConfirmationWindow?.onCancel = { [weak self] in
            print("❌ 用户取消关机")
            self?.shutdownConfirmationWindow = nil
        }
        
        // 显示对话框
        shutdownConfirmationWindow?.showWithAnimation()
    }
    
    // MARK: - Testing Support
    
    /// 测试专用：触发关机按钮点击事件
    internal func triggerShutdownButtonForTesting() {
        shutdownButtonClicked()
    }
    
    private func triggerSystemShutdown() {
        // 测试环境下不执行任何真实关机动作
        if isRunningUnitTests() {
            print("🧪 [TEST] 跳过真实关机执行")
            return
        }
        print("🔴 执行系统关机")
        
        // 使用AppleScript触发系统关机
        let script = """
        tell application "System Events"
            shut down
        end tell
        """
        
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            
            if let error = error {
                print("❌ 关机脚本执行失败: \(error)")
                // 如果AppleScript失败，尝试使用命令行
                fallbackShutdown()
            }
        } else {
            fallbackShutdown()
        }
    }
    
    private func fallbackShutdown() {
        // 测试环境下不执行任何真实关机动作
        if isRunningUnitTests() {
            print("🧪 [TEST] 跳过备用关机方法")
            return
        }
        print("🔴 使用备用关机方法")
        
        let task = Process()
        task.launchPath = "/usr/bin/sudo"
        task.arguments = ["shutdown", "-h", "now"]
        
        do {
            try task.run()
            print("✅ 关机命令已执行")
        } catch {
            print("❌ 关机命令执行失败: \(error)")
            
            // 最后的备用方案：显示系统关机对话框
            showSystemShutdownDialog()
        }
    }
    
    private func showSystemShutdownDialog() {
        // 测试环境下不弹出系统关机对话框
        if isRunningUnitTests() {
            print("🧪 [TEST] 跳过系统关机对话框")
            return
        }
        // 使用系统的关机对话框
        let script = """
        tell application "loginwindow"
            «event aevtshut»
        end tell
        """
        
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            
            if let error = error {
                print("❌ 系统关机对话框调用失败: \(error)")
            }
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // 不绘制背景，让视频透过显示
        // 文字现在通过 NSTextField 显示，不需要在这里绘制
    }
    
    override func mouseDown(with event: NSEvent) {
        // 点击后不再隐藏遮罩层，移除处理逻辑
        // onDismiss?()
    }
    
    override func keyDown(with event: NSEvent) {
        // 检查是否是 ESC 键
        if event.keyCode == 53 { // ESC 键的键码是 53
            // 如果是强制睡眠状态，禁止ESC键退出
            if let timer = timer, timer.isStayUpTime {
                print("🚫 强制睡眠期间，ESC键被禁用")
                return
            }
            if let window = self.window as? OverlayWindow {
                window.dismissOverlay(reason: isPreviewMode ? .preview : .user)
            }
        } else {
            super.keyDown(with: event)
        }
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
}
