//
//  OnboardingWindow.swift
//  PomodoroScreen
//
//  Created by Assistant on 2025-09-22.
//  Modified by Assistant on 2025-09-22.
//

import Cocoa

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
    private var contentLabel: NSTextField!
    private var stepIndicator: NSStackView!
    private var imageView: NSImageView!
    private var nextButton: HoverButton!
    private var skipButton: NSButton!
    private var progressView: NSProgressIndicator!
    
    // MARK: - Initialization
    
    init() {
        let windowSize = NSSize(width: 480, height: 360)
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
        
        // 设置背景色
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        setupTitleLabel(in: contentView)
        setupImageView(in: contentView)
        setupContentLabel(in: contentView)
        setupProgressView(in: contentView)
        setupStepIndicator(in: contentView)
        setupButtons(in: contentView)
    }
    
    private func setupTitleLabel(in contentView: NSView) {
        titleLabel = NSTextField(frame: NSRect(x: 40, y: 280, width: 400, height: 40))
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.isBordered = false
        titleLabel.backgroundColor = NSColor.clear
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = NSColor.labelColor
        titleLabel.alignment = .center
        contentView.addSubview(titleLabel)
    }
    
    private func setupImageView(in contentView: NSView) {
        imageView = NSImageView(frame: NSRect(x: 190, y: 180, width: 100, height: 80))
        imageView.imageScaling = .scaleProportionallyUpOrDown
        contentView.addSubview(imageView)
    }
    
    private func setupContentLabel(in contentView: NSView) {
        contentLabel = NSTextField(frame: NSRect(x: 40, y: 100, width: 400, height: 60))
        contentLabel.isEditable = false
        contentLabel.isSelectable = false
        contentLabel.isBordered = false
        contentLabel.backgroundColor = NSColor.clear
        contentLabel.font = NSFont.systemFont(ofSize: 14)
        contentLabel.textColor = NSColor.secondaryLabelColor
        contentLabel.alignment = .center
        contentLabel.maximumNumberOfLines = 3
        contentView.addSubview(contentLabel)
    }
    
    private func setupProgressView(in contentView: NSView) {
        progressView = NSProgressIndicator(frame: NSRect(x: 40, y: 75, width: 400, height: 6))
        progressView.style = .bar
        progressView.isIndeterminate = false
        progressView.minValue = 0
        progressView.maxValue = Double(totalSteps)
        contentView.addSubview(progressView)
    }
    
    private func setupStepIndicator(in contentView: NSView) {
        stepIndicator = NSStackView(frame: NSRect(x: 190, y: 45, width: 100, height: 20))
        stepIndicator.orientation = .horizontal
        stepIndicator.distribution = .fillEqually
        stepIndicator.spacing = 8
        
        for _ in 0..<totalSteps {
            let dot = NSView(frame: NSRect(x: 0, y: 0, width: 8, height: 8))
            dot.wantsLayer = true
            dot.layer?.cornerRadius = 4
            dot.layer?.backgroundColor = NSColor.tertiaryLabelColor.cgColor
            stepIndicator.addArrangedSubview(dot)
        }
        
        contentView.addSubview(stepIndicator)
    }
    
    private func setupButtons(in contentView: NSView) {
        // 下一步/完成按钮 - 右下角位置，距离底部和右边缘各20px
        nextButton = HoverButton(frame: NSRect(x: 380, y: 20, width: 80, height: 32))
        nextButton.configurePrimaryStyle(title: "下一步")
        nextButton.target = self
        nextButton.action = #selector(nextButtonClicked)
        contentView.addSubview(nextButton)
        
        // 跳过按钮 - 左下角位置，距离底部和左边缘各20px
        skipButton = NSButton(frame: NSRect(x: 20, y: 20, width: 80, height: 32))
        skipButton.title = "跳过"
        skipButton.bezelStyle = .rounded
        skipButton.font = NSFont.systemFont(ofSize: 13)
        skipButton.target = self
        skipButton.action = #selector(skipButtonClicked)
        contentView.addSubview(skipButton)
    }
    
    // MARK: - Content Updates
    
    private func updateContent() {
        switch currentStep {
        case 0:
            titleLabel.stringValue = "欢迎使用 PomodoroScreen! "
            contentLabel.stringValue = "PomodoroScreen 是一款专业的番茄钟应用\n帮助您提高专注力，保持工作与休息的平衡\n让我们开始简单的引导吧"
            imageView.image = NSImage(named: "Icon")
            nextButton.title = "开始引导"
            
        case 1:
            titleLabel.stringValue = "状态栏图标"
            contentLabel.stringValue = "应用启动后，您会在屏幕右上角的状态栏中\n看到一个动态时钟图标，显示当前倒计时进度\n点击它可以查看详细进度和控制计时器"
            // 使用ClockIconGenerator生成大尺寸示例时钟图标 (显示75%进度)
            let clockGenerator = ClockIconGenerator()
            imageView.image = clockGenerator.generateLargeClockIcon(progress: 0.75, size: CGSize(width: 80, height: 80))
            nextButton.title = "我知道了"
            
        case 2:
            titleLabel.stringValue = "设置和个性化 ⚙️"
            contentLabel.stringValue = "右键点击状态栏图标可以打开设置菜单\n您可以自定义工作时长、休息时长\n以及其他个性化选项来适应您的工作习惯"
            imageView.image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: "设置选项")
            nextButton.title = "开始使用"
            
        default:
            break
        }
        
        // 更新进度
        progressView.doubleValue = Double(currentStep + 1)
        
        // 更新步骤指示器
        for (index, view) in stepIndicator.arrangedSubviews.enumerated() {
            view.layer?.backgroundColor = index <= currentStep ? 
                NSColor.controlAccentColor.cgColor : 
                NSColor.tertiaryLabelColor.cgColor
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
        // 保存已完成引导的标记
        UserDefaults.standard.set(true, forKey: "OnboardingCompleted")
        
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
        return !UserDefaults.standard.bool(forKey: "OnboardingCompleted")
    }
    
    static func resetOnboarding() {
        UserDefaults.standard.removeObject(forKey: "OnboardingCompleted")
    }
}
