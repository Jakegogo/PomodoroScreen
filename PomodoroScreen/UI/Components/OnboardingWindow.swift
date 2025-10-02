//
//  OnboardingWindow.swift
//  PomodoroScreen
//
//  Created by Assistant on 2025-09-22.
//  Modified by Assistant on 2025-09-22.
//

import Cocoa
import AVFoundation

/// 新手引导窗口
/// 
/// 功能特性:
/// - 首次启动时显示引导界面
/// - 指引用户了解状态栏图标位置
/// - 指引用户了解设置打开方式
/// - 美观的现代化界面设计
/// - 支持跳过和完成引导
class OnboardingWindow: NSWindow {
    
    // MARK: - Properties
    
    private var currentStep = 0
    private let totalSteps = 3
    private var onboardingCompleted: (() -> Void)?
    
    // UI Components
    private var titleLabel: NSTextField!
    private var appNameLabel: NSTextField!
    private var contentLabel: NSTextField!
    private var stepIndicator: NSStackView!
    private var imageView: NSImageView!
    private var nextButton: HoverButton!
    private var skipButton: NSButton!
    private var progressView: NSProgressIndicator!
    
    // Video Components
    private var videoContainerView: NSView!
    private var cardView: NSView!
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    
    // MARK: - Initialization
    
    deinit {
        cleanupVideoPlayer()
    }
    
    init() {
        let windowSize = NSSize(width: 560, height: 680)
        let windowFrame = NSRect(
            x: (NSScreen.main?.frame.width ?? 1200 - windowSize.width) / 2,
            y: (NSScreen.main?.frame.height ?? 800 - windowSize.height) / 2,
            width: windowSize.width,
            height: windowSize.height
        )
        
        super.init(
            contentRect: windowFrame,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
        setupUI()
        updateContent()
    }
    
    // MARK: - Window Setup
    
    private func setupWindow() {
        self.title = "欢迎使用 PomodoroScreen"
        self.level = .floating
        self.isReleasedWhenClosed = false
        self.center()
        
        // 设置窗口样式
        self.titlebarAppearsTransparent = false
        self.titleVisibility = .visible
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        guard let contentView = self.contentView else { return }
        
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        // 卡片容器（全屏充满，无外边距）
        cardView = NSView(frame: NSRect(x: 0, y: 0, width: contentView.bounds.width, height: contentView.bounds.height))
        cardView.autoresizingMask = [.width, .height]
        cardView.wantsLayer = true
        cardView.layer?.backgroundColor = NSColor.white.cgColor
        cardView.layer?.cornerRadius = 0
        // 去除阴影，贴边显示
        cardView.layer?.shadowOpacity = 0
        cardView.layer?.shadowRadius = 0
        cardView.layer?.shadowOffset = .zero
        contentView.addSubview(cardView)
        
        setupTitleLabels(in: cardView)
        setupImageView(in: cardView)
        setupVideoContainer(in: cardView)
        setupContentLabel(in: cardView)
        setupProgressView(in: cardView)
        setupStepIndicator(in: cardView)
        setupButtons(in: cardView)
    }
    
    private func setupTitleLabels(in container: NSView) {
        // 欢迎标题
        titleLabel = NSTextField(frame: NSRect(x: 24, y: container.bounds.height - 130, width: container.bounds.width - 48, height: 36))
        titleLabel.autoresizingMask = [.minYMargin, .width]
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.isBordered = false
        titleLabel.backgroundColor = NSColor.clear
        titleLabel.font = NSFont.systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = NSColor.labelColor
        titleLabel.alignment = .center
        container.addSubview(titleLabel)
        
        // 应用名标题
        appNameLabel = NSTextField(frame: NSRect(x: 24, y: container.bounds.height - 170, width: container.bounds.width - 48, height: 44))
        appNameLabel.autoresizingMask = [.minYMargin, .width]
        appNameLabel.isEditable = false
        appNameLabel.isSelectable = false
        appNameLabel.isBordered = false
        appNameLabel.backgroundColor = NSColor.clear
        appNameLabel.font = NSFont.systemFont(ofSize: 34, weight: .heavy)
        appNameLabel.textColor = NSColor.labelColor
        appNameLabel.alignment = .center
        container.addSubview(appNameLabel)
    }
    
    private func setupImageView(in contentView: NSView) {
        imageView = NSImageView(frame: NSRect(x: (contentView.bounds.width - 120)/2, y: contentView.bounds.height - 300, width: 120, height: 96))
        imageView.autoresizingMask = [.minYMargin, .minXMargin, .maxXMargin]
        imageView.imageScaling = .scaleProportionallyUpOrDown
        contentView.addSubview(imageView)
    }
    
    private func setupVideoContainer(in contentView: NSView) {
        videoContainerView = NSView(frame: NSRect(x: (contentView.bounds.width - 160)/2, y: contentView.bounds.height - 340, width: 160, height: 120))
        videoContainerView.wantsLayer = true
        videoContainerView.layer?.masksToBounds = true
        videoContainerView.layer?.cornerRadius = 8
        videoContainerView.layer?.backgroundColor = NSColor.clear.cgColor
        videoContainerView.isHidden = true // 默认隐藏，只在第一步显示
        contentView.addSubview(videoContainerView)
        print("视频容器已创建: \(videoContainerView.frame)")
    }
    
    private func setupContentLabel(in contentView: NSView) {
        contentLabel = NSTextField(frame: NSRect(x: 24, y: 240, width: contentView.bounds.width - 48, height: 66))
        contentLabel.autoresizingMask = [.width]
        contentLabel.isEditable = false
        contentLabel.isSelectable = false
        contentLabel.isBordered = false
        contentLabel.backgroundColor = NSColor.clear
        contentLabel.font = NSFont.systemFont(ofSize: 15)
        contentLabel.textColor = NSColor.secondaryLabelColor
        contentLabel.alignment = .center
        contentLabel.maximumNumberOfLines = 3
        contentView.addSubview(contentLabel)
    }
    
    private func setupProgressView(in contentView: NSView) {
        progressView = NSProgressIndicator(frame: NSRect(x: 24, y: 200, width: contentView.bounds.width - 48, height: 8))
        progressView.autoresizingMask = [.width]
        progressView.style = .bar
        progressView.isIndeterminate = false
        progressView.minValue = 0
        progressView.maxValue = Double(totalSteps)
        contentView.addSubview(progressView)
    }
    
    private func setupStepIndicator(in contentView: NSView) {
        stepIndicator = NSStackView(frame: NSRect(x: (contentView.bounds.width - 120)/2, y: 175, width: 120, height: 20))
        stepIndicator.autoresizingMask = [.minXMargin, .maxXMargin]
        stepIndicator.orientation = .horizontal
        stepIndicator.distribution = .fillEqually
        stepIndicator.spacing = 8
        
        for i in 0..<totalSteps {
            let dot = NSView(frame: NSRect(x: 0, y: 0, width: 12, height: 12))
            dot.wantsLayer = true
            dot.layer?.cornerRadius = 6
            dot.layer?.backgroundColor = NSColor.tertiaryLabelColor.withAlphaComponent(0.28).cgColor
            dot.identifier = NSUserInterfaceItemIdentifier("step_\(i)")
            let tap = NSClickGestureRecognizer(target: self, action: #selector(stepDotTapped(_:)))
            dot.addGestureRecognizer(tap)
            stepIndicator.addArrangedSubview(dot)
        }
        
        contentView.addSubview(stepIndicator)
    }

    @objc private func stepDotTapped(_ sender: NSClickGestureRecognizer) {
        guard let id = sender.view?.identifier?.rawValue else { return }
        guard let idxStr = id.split(separator: "_").last, let index = Int(idxStr) else { return }
        guard index >= 0 && index < totalSteps else { return }
        if index == currentStep { return }
        currentStep = index
        updateContent()
    }
    
    private func setupButtons(in contentView: NSView) {
        // 下一步/完成按钮 - 右下角位置
        nextButton = HoverButton(frame: NSRect(x: contentView.bounds.width - 160 - 24, y: 16, width: 160, height: 44))
        nextButton.autoresizingMask = [.minXMargin]
        nextButton.configurePrimaryStyle(title: "下一步")
        nextButton.target = self
        nextButton.action = #selector(nextButtonClicked)
        contentView.addSubview(nextButton)
        
        // 跳过按钮 - 左下角位置
        skipButton = NSButton(frame: NSRect(x: 24, y: 16, width: 80, height: 44))
        skipButton.title = "跳过"
        skipButton.bezelStyle = .rounded
        skipButton.font = NSFont.systemFont(ofSize: 13)
        skipButton.target = self
        skipButton.action = #selector(skipButtonClicked)
        contentView.addSubview(skipButton)
    }
    
    // MARK: - Video Setup
    
    private func setupVideoPlayer() {
        // 清理之前的播放器
        cleanupVideoPlayer()
        
        // 获取视频文件路径
        guard let videoURL = Bundle.main.url(forResource: "icon_video", withExtension: "mp4") else {
            print("找不到视频文件：icon_video.mp4")
            // 调试信息：列出所有资源文件
            if let resourcePath = Bundle.main.resourcePath {
                print("资源目录: \(resourcePath)")
                let fileManager = FileManager.default
                do {
                    let contents = try fileManager.contentsOfDirectory(atPath: resourcePath)
                    print("资源文件列表: \(contents)")
                } catch {
                    print("无法读取资源目录: \(error)")
                }
            }
            return
        }
        
        print("成功找到视频文件: \(videoURL)")
        print("视频容器大小: \(videoContainerView.bounds)")
        
        // 创建播放器
        player = AVPlayer(url: videoURL)
        guard let player = player else { return }
        
        // 创建播放器图层
        playerLayer = AVPlayerLayer(player: player)
        guard let playerLayer = playerLayer else { return }
        
        playerLayer.frame = videoContainerView.bounds
        playerLayer.videoGravity = .resizeAspectFill
        
        // 添加到容器视图
        videoContainerView.layer?.addSublayer(playerLayer)
        
        // 确保图层大小正确更新
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.playerLayer?.frame = self.videoContainerView.bounds
        }
        
        // 设置循环播放
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(videoDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem
        )
        
        // 开始播放
        player.play()
    }
    
    @objc private func videoDidFinishPlaying() {
        // 循环播放
        player?.seek(to: .zero)
        player?.play()
    }
    
    private func cleanupVideoPlayer() {
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        player?.pause()
        playerLayer?.removeFromSuperlayer()
        player = nil
        playerLayer = nil
    }
    
    // MARK: - Content Updates
    
    private func updateContent() {
        switch currentStep {
        case 0:
            titleLabel.stringValue = "欢迎使用"
            appNameLabel.stringValue = "PomodoroScreen!"
            contentLabel.stringValue = "PomodoroScreen 是一款专业的番茄钟应用\n帮助您提高专注力，保持工作与休息的平衡"
            // 显示视频而不是静态图标
            print("第一步：隐藏图像视图，显示视频容器")
            imageView.isHidden = true
            videoContainerView.isHidden = false
            print("视频容器可见性: \(!videoContainerView.isHidden)")
            print("图像视图可见性: \(!imageView.isHidden)")
            setupVideoPlayer()
            nextButton.title = "开始引导"
            
        case 1:
            titleLabel.stringValue = "状态栏图标"
            appNameLabel.stringValue = ""
            contentLabel.stringValue = "应用启动后，您会在屏幕右上角的状态栏中\n看到一个动态时钟图标，显示当前倒计时进度\n点击它可以查看详细进度和控制计时器"
            // 隐藏视频，显示图像
            cleanupVideoPlayer()
            videoContainerView.isHidden = true
            imageView.isHidden = false
            // 使用ClockIconGenerator生成大尺寸示例时钟图标 (显示75%进度)
            let clockGenerator = ClockIconGenerator()
            imageView.image = clockGenerator.generateLargeClockIcon(progress: 0.75, size: CGSize(width: 80, height: 80))
            nextButton.title = "我知道了"
            
        case 2:
            titleLabel.stringValue = "设置和个性化 ⚙️"
            appNameLabel.stringValue = ""
            contentLabel.stringValue = "右键点击状态栏图标可以打开设置菜单\n您可以自定义工作时长、休息时长\n以及其他个性化选项来适应您的工作习惯"
            // 确保视频已停止，显示图像
            cleanupVideoPlayer()
            videoContainerView.isHidden = true
            imageView.isHidden = false
            imageView.image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: "设置选项")
            nextButton.title = "开始使用"
            
        default:
            break
        }
        
        // 更新进度
        progressView.doubleValue = Double(currentStep + 1)
        
        // 更新步骤指示器
        for (index, view) in stepIndicator.arrangedSubviews.enumerated() {
            if let layer = view.layer {
                layer.backgroundColor = (index == currentStep) ? NSColor.controlAccentColor.cgColor : NSColor.tertiaryLabelColor.withAlphaComponent(0.28).cgColor
            }
            view.isHidden = false
            view.isHidden = false
        }
        
        // 更新跳过按钮可见性
        skipButton.isHidden = currentStep >= totalSteps - 1
    }
    
    // MARK: - Actions
    
    @objc private func nextButtonClicked() {
        if currentStep < totalSteps - 1 {
            currentStep += 1
            updateContent()
        } else {
            completeOnboarding()
        }
    }
    
    @objc private func skipButtonClicked() {
        completeOnboarding()
    }
    
    private func completeOnboarding() {
        // 清理视频播放器
        cleanupVideoPlayer()
        
        // 保存已完成引导的标记
        SettingsStore.onboardingCompleted = true
        
        // 执行完成回调
        onboardingCompleted?()
        
        // 关闭窗口
        self.close()
    }
    
    // MARK: - Public Methods
    
    func setOnboardingCompletedHandler(_ handler: @escaping () -> Void) {
        onboardingCompleted = handler
    }
    
    static func shouldShowOnboarding() -> Bool {
        return !SettingsStore.onboardingCompleted
    }
    
    static func resetOnboarding() {
        SettingsStore.remove("OnboardingCompleted")
    }
}
