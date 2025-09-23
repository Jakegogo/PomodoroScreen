import Cocoa
import AVFoundation

class OverlayWindow: NSWindow {
    
    // MARK: - Properties
    
    private var overlayView: OverlayView!
    private var dismissTimer: Timer?
    private var timer: PomodoroTimer? // 添加timer引用
    private var isPreviewMode: Bool = false // 预览模式标志
    
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
    }
    
    private func setupOverlayProperties() {
        // 设置窗口层级为最高
        level = .screenSaver
        
        // 覆盖所有桌面空间
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        
        // 禁用标准窗口行为
        styleMask = [.borderless]
        
        // 确保窗口覆盖整个屏幕
        if let screen = NSScreen.main {
            setFrame(screen.frame, display: true)
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
            self?.dismissOverlay()
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
            // 如果没有背景文件，查找默认的 MP4 文件
            if let videoURL = findVideoFile() {
                setupPlayer(with: videoURL)
            }
        } else {
            // 使用配置的背景文件
            setupBackgroundFromFiles()
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
            
            print("✅ 成功加载图片背景: \(url.lastPathComponent), 原始尺寸: \(imageSize), 缩放后: \(scaledWidth)x\(scaledHeight)")
        } else {
            print("❌ 无法加载图片: \(url.path)")
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
        // 首先在应用程序包中查找
        if let bundleVideoURL = Bundle.main.url(forResource: "rest_video", withExtension: "mp4") {
            return bundleVideoURL
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
        
        // 设置3分钟（180秒）后自动隐藏
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 180.0, repeats: false) { [weak self] _ in
            self?.dismissOverlay()
        }
    }
    
    private func dismissOverlay() {
        // 清除定时器
        dismissTimer?.invalidate()
        dismissTimer = nil
        backgroundRotationTimer?.invalidate()
        backgroundRotationTimer = nil
        
        // 停止并清理背景
        cleanupBackground()
        
        // 只有在非预览模式下才通知计时器
        if !isPreviewMode, let timer = self.timer {
            // 如果是用户主动取消休息，调用cancelBreak
            // 如果是自动结束，则开始下一个番茄钟
            if timer.isInRestPeriod {
                timer.cancelBreak()
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

class OverlayView: NSView {
    
    var onDismiss: (() -> Void)?
    private var cancelButton: NSButton!
    private var messageLabel: NSTextField!
    private var timer: PomodoroTimer?
    private var isPreviewMode: Bool = false
    
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
            setupPreviewButton()
        } else {
            // 根据设置决定是否显示取消休息按钮
            let shouldShowButton = timer?.shouldShowCancelRestButton ?? true
            if shouldShowButton {
                setupCancelButton()
            }
        }
    }
    
    private func setupMessageLabel() {
        messageLabel = NSTextField(frame: NSRect(x: 0, y: 0, width: 800, height: 200))
        
        if isPreviewMode {
            // 预览模式显示预览标题
            messageLabel.stringValue = "背景预览"
        } else {
            // 正常模式根据是否为熬夜时间显示不同消息
            if let timer = timer, timer.isStayUpTime {
                messageLabel.stringValue = "🌙 熬夜时间到了，该休息了！\n\n为了您的健康，请停止工作"
            } else {
                // 获取当前休息时间信息并显示
                if let timer = timer {
                    let breakInfo = timer.getCurrentBreakInfo()
                    let breakType = breakInfo.isLongBreak ? "长休息" : "休息"
                    messageLabel.stringValue = "番茄钟时间到！\n\n\(breakType)时间，\(breakInfo.breakMinutes)分钟后自动恢复"
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
    
        private func setupCancelButton() {
            cancelButton = NSButton(frame: NSRect(x: 0, y: 0, width: 90, height: 32))
            cancelButton.title = "取消休息"
            cancelButton.bezelStyle = .shadowlessSquare
            cancelButton.isBordered = false
            cancelButton.font = NSFont.systemFont(ofSize: 14, weight: .regular)
            cancelButton.target = self
            cancelButton.action = #selector(cancelButtonClicked)
            
            // 设置完全透明背景和白色边框（更精致的样式）
            cancelButton.wantsLayer = true
            cancelButton.layer?.backgroundColor = NSColor.clear.cgColor
            cancelButton.layer?.cornerRadius = 6
            cancelButton.layer?.borderWidth = 1.5
            cancelButton.layer?.borderColor = NSColor.white.cgColor
            
            // 设置文字颜色为白色
            cancelButton.contentTintColor = NSColor.white
            
            addSubview(cancelButton)
        
        // 设置按钮位置（类似苹果锁屏密码输入框的位置，屏幕下方1/3处）
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cancelButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -bounds.height * 0.2), // 距离底部约20%的位置
            cancelButton.widthAnchor.constraint(equalToConstant: 90),
            cancelButton.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        // 3秒后淡化按钮（但不完全消失）
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.fadeCancelButton()
        }
    }
    
    private func fadeCancelButton() {
        guard let cancelButton = cancelButton else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 1.0 // 淡化动画持续1秒
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            cancelButton.animator().alphaValue = 0.4 // 淡化到40%透明度，仍然可见和可点击
        }, completionHandler: { [weak self] in
            // 动画完成后启用鼠标悬停效果
            self?.enableButtonHoverEffect()
        })
    }
    
    private func setupPreviewButton() {
        cancelButton = NSButton(frame: NSRect(x: 0, y: 0, width: 90, height: 32))
        cancelButton.title = "关闭预览"
        cancelButton.bezelStyle = .shadowlessSquare
        cancelButton.isBordered = false
        cancelButton.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        cancelButton.target = self
        cancelButton.action = #selector(previewButtonClicked)
        cancelButton.keyEquivalent = "\u{1b}" // ESC键
        
        // 设置完全透明背景和白色边框（与 CancelButton 相同的样式）
        cancelButton.wantsLayer = true
        cancelButton.layer?.backgroundColor = NSColor.clear.cgColor
        cancelButton.layer?.cornerRadius = 6
        cancelButton.layer?.borderWidth = 1.5
        cancelButton.layer?.borderColor = NSColor.white.cgColor
        
        // 设置文字颜色为白色
        cancelButton.contentTintColor = NSColor.white
        
        addSubview(cancelButton)
        
        // 设置按钮位置（与 CancelButton 相同的位置）
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cancelButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -bounds.height * 0.2), // 距离底部约20%的位置
            cancelButton.widthAnchor.constraint(equalToConstant: 90),
            cancelButton.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        // 3秒后淡化按钮（但不完全消失）
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.fadeCancelButton()
        }
        
        // 添加提示标签
        let hintLabel = NSTextField(labelWithString: "按 ESC 键或点击关闭按钮退出预览")
        hintLabel.font = NSFont.systemFont(ofSize: 14)
        hintLabel.textColor = NSColor.white.withAlphaComponent(0.8)
        hintLabel.alignment = .center
        addSubview(hintLabel)
        
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hintLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            hintLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -50),
            hintLabel.widthAnchor.constraint(equalToConstant: 400),
            hintLabel.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    private func enableButtonHoverEffect() {
        guard let cancelButton = cancelButton else { return }
        
        // 创建鼠标追踪区域
        let trackingArea = NSTrackingArea(
            rect: cancelButton.bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: ["button": "cancel"]
        )
        cancelButton.addTrackingArea(trackingArea)
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        
        // 检查是否是取消按钮的悬停事件
        if let userInfo = event.trackingArea?.userInfo as? [String: String],
           userInfo["button"] == "cancel",
           let cancelButton = cancelButton {
            
            // 鼠标进入时恢复完全不透明
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2 // 快速动画
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                cancelButton.animator().alphaValue = 1.0
            }, completionHandler: nil)
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        
        // 检查是否是取消按钮的悬停事件
        if let userInfo = event.trackingArea?.userInfo as? [String: String],
           userInfo["button"] == "cancel",
           let cancelButton = cancelButton {
            
            // 鼠标离开时恢复半透明
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2 // 快速动画
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                cancelButton.animator().alphaValue = 0.4
            }, completionHandler: nil)
        }
    }
    
    @objc private func cancelButtonClicked() {
        onDismiss?()
    }
    
    @objc private func previewButtonClicked() {
        onDismiss?()
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
        // 按键后不再隐藏遮罩层，移除处理逻辑
        // onDismiss?()
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
}
