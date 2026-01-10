//
//  ReportWindow.swift
//  PomodoroScreen
//
//  Created by Assistant on 2025-09-21.
//

import Cocoa
import WebKit

class ReportWindow: NSWindow {
    
    private var webView: WKWebView!
    private var reportData: ReportData?
    private var reportBaseURL: URL?
    // 自定义居中标题视图容器
    private var centeredTitleContainer: NSStackView?
    
    convenience init() {
        let windowFrame = NSRect(x: 100, y: 100, width: 1200, height: 800)
        
        self.init(
            contentRect: windowFrame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
        setupWebView()
    }
    
    private func setupWindow() {
        self.title = "今日时间"
        self.center()
        self.isReleasedWhenClosed = false
        self.minSize = NSSize(width: 800, height: 600)
        
        // 设置窗口样式
        self.titlebarAppearsTransparent = false
        self.backgroundColor = NSColor.windowBackgroundColor

        // 在标题中间添加图标+标题
        centeredTitleContainer = TitlebarIconManager.setCenteredTitle(
            window: self,
            text: "今日时间",
            iconResource: "statistics",
            ext: "svg",
            iconSize: NSSize(width: 20, height: 20)
        )
    }
    
    private func setupWebView() {
        // 添加控制台消息处理
        let userContentController = WKUserContentController()
        let consoleLogScript = """
            window.console = (function(oldConsole) {
                return {
                    log: function(...args) {
                        oldConsole.log(...args);
                        window.webkit.messageHandlers.consoleLog.postMessage(args.join(' '));
                    },
                    warn: function(...args) {
                        oldConsole.warn(...args);
                        window.webkit.messageHandlers.consoleWarn.postMessage(args.join(' '));
                    },
                    error: function(...args) {
                        oldConsole.error(...args);
                        window.webkit.messageHandlers.consoleError.postMessage(args.join(' '));
                    }
                };
            })(window.console);
        """
        
        let consoleScript = WKUserScript(source: consoleLogScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        userContentController.addUserScript(consoleScript)
        userContentController.add(self, name: "consoleLog")
        userContentController.add(self, name: "consoleWarn")
        userContentController.add(self, name: "consoleError")
        userContentController.add(self, name: "saveMood")
        userContentController.add(self, name: "saveReportImage")
        
        // 配置WebView
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.preferences.javaScriptEnabled = true
        webConfiguration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        webConfiguration.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        webConfiguration.userContentController = userContentController
        
        // 启用开发者工具（用于调试）
        if #available(macOS 13.3, *) {
            webConfiguration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        }
        
        // 创建WebView
        webView = WKWebView(frame: self.contentView!.bounds, configuration: webConfiguration)
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        webView.uiDelegate = self
        
        self.contentView?.addSubview(webView)
    }
    
    // MARK: - 报告显示
    
    func showReport(with data: ReportData) {
        self.reportData = data
        loadReportHTML(data)
        self.makeKeyAndOrderFront(nil)
    }
    
    override func close() {
        super.close()
        // 不释放，保持单例窗口的可复用性（外部持有引用）
        self.orderOut(nil)
    }
    
    private func loadReportHTML(_ data: ReportData) {
        do {
            let htmlContent = try generateReportHTMLFromFile(data)
            webView.loadHTMLString(htmlContent, baseURL: reportBaseURL)
        } catch {
            print("❌ 无法加载报告HTML文件: \(error)")
            // HTML文件加载失败，报告窗口无法显示
            webView.loadHTMLString("<html><body><h1>报告加载失败</h1><p>无法找到报告模板文件</p></body></html>", baseURL: nil)
        }
    }
    
    private func generateReportHTMLFromFile(_ data: ReportData) throws -> String {
        // 读取HTML模板文件
        guard let htmlPath = Bundle.main.path(forResource: "report", ofType: "html") else {
            throw NSError(domain: "ReportWindow", code: 1, userInfo: [NSLocalizedDescriptionKey: "找不到report.html文件"])
        }
        
        var htmlTemplate = try String(contentsOfFile: htmlPath, encoding: .utf8)
        // 记录用于解析相对资源路径的基准URL（与report.html同级目录）
        reportBaseURL = URL(fileURLWithPath: htmlPath).deletingLastPathComponent()
        
        // 准备Chart.js脚本
        let chartJSScript = getChartJSScript()
        
        // 准备报告数据
        let jsonData = data.toJSONString() ?? "{}"
        
        // 在HTML中注入Chart.js和数据
        // 在</head>之前插入Chart.js脚本
        htmlTemplate = htmlTemplate.replacingOccurrences(
            of: "</head>",
            with: "\(chartJSScript)\n</head>"
        )
        
        // 在</body>之前插入数据脚本
        let dataScript = """
        <script>
            // 报告数据
            const reportData = \(jsonData);
            // 保存心情接口（通过WebKit桥发送到原生）
            function saveMoodToNative(moodLevel, moodNote) {
                try {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.saveMood) {
                        window.webkit.messageHandlers.saveMood.postMessage({ level: moodLevel, note: moodNote ?? '' });
                    } else {
                        console.warn('saveMood bridge not available');
                    }
                } catch (e) {
                    console.error('saveMood bridge error:', e);
                }
            }
        </script>
        """
        
        htmlTemplate = htmlTemplate.replacingOccurrences(
            of: "</body>",
            with: "\(dataScript)\n</body>"
        )
        
        return htmlTemplate
    }
    
    // MARK: - Screenshot & Share
    private func captureReportSnapshotAndShare() {
        // 先通过 JS 计算完整文档尺寸（macOS 上无 scrollView 属性）
        let sizeJS = "(function(){var de=document.documentElement,db=document.body;return {w: Math.max(de.scrollWidth, db?db.scrollWidth:0), h: Math.max(de.scrollHeight, db?db.scrollHeight:0)};})()"
        webView.evaluateJavaScript(sizeJS) { [weak self] result, error in
            guard let self = self else { return }
            var contentSize = self.webView.bounds.size
            if error == nil, let dict = result as? [String: Any] {
                if let wNum = dict["w"] as? NSNumber, let hNum = dict["h"] as? NSNumber {
                    let w = CGFloat(truncating: wNum)
                    let h = CGFloat(truncating: hNum)
                    if w > 0 && h > 0 { contentSize = CGSize(width: w, height: h) }
                }
            }
            let config = WKSnapshotConfiguration()
            config.afterScreenUpdates = true
            // 调整 WebView 尺寸为文档完整高度以避免滚动方式
            let originalFrame = self.webView.frame
            let newWidth = max(originalFrame.size.width, contentSize.width)
            let newFrame = NSRect(x: originalFrame.origin.x, y: originalFrame.origin.y, width: newWidth, height: contentSize.height)
            self.webView.frame = newFrame
            self.webView.layout() // 强制布局
            self.webView.display() // 强制绘制
            config.rect = self.webView.bounds
            if #available(macOS 11.0, *) {
                config.snapshotWidth = NSNumber(value: Double(self.webView.bounds.width))
            }
            self.webView.takeSnapshot(with: config) { [weak self] image, error in
                guard let self = self else { return }
                // 立即恢复原尺寸
                self.webView.frame = originalFrame
                self.webView.layout()
                self.webView.display()
                if let image = image {
                    // 保存到下载目录
                    if let data = self.pngData(from: image) {
                        let fm = FileManager.default
                        if let downloads = fm.urls(for: .downloadsDirectory, in: .userDomainMask).first {
                            let formatter = DateFormatter()
                            formatter.dateFormat = "yyyyMMdd-HHmmss"
                            let ts = formatter.string(from: Date())
                            let fileURL = downloads.appendingPathComponent("PomodoroReport-\(ts).png")
                            do {
                                try data.write(to: fileURL)
                            } catch {
                                print("❌ 保存截图失败: \(error)")
                                self.notifyShareResult(success: false, fileURL: nil)
                                return
                            }
                            // 复制到剪贴板（同时写入图片与文件URL）
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.writeObjects([image])
                            pasteboard.writeObjects([fileURL as NSURL])
                            self.notifyShareResult(success: true, fileURL: fileURL)
                        }
                    }
                } else if let error = error {
                    print("❌ 截图失败: \(error.localizedDescription)")
                    self.notifyShareResult(success: false, fileURL: nil)
                }
            }
        }
    }
    
    private func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
    
    private func notifyShareResult(success: Bool, fileURL: URL?) {
        let status = success ? "success" : "error"
        var payload: [String: Any] = ["status": status]
        if let fileURL { payload["filePath"] = fileURL.path }
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let json = String(data: data, encoding: .utf8) {
            let js = "if (window.__reportShareCallbackFromNative) { window.__reportShareCallbackFromNative(\(json)); }"
            DispatchQueue.main.async { [weak self] in
                self?.webView.evaluateJavaScript(js, completionHandler: nil)
            }
        }
    }
    
    private func getChartJSScript() -> String {
        // 尝试使用本地Chart.js文件
        if let chartJSPath = Bundle.main.path(forResource: "chart", ofType: "js") {
            do {
                let chartJSContent = try String(contentsOfFile: chartJSPath, encoding: .utf8)
                return "<script>\(chartJSContent)</script>"
            } catch {
                print("⚠️ 无法读取Chart.js文件: \(error)")
            }
        } else {
            print("⚠️ 找不到Chart.js文件")
        }
        
        // 如果本地文件读取失败，使用CDN作为后备
        print("📡 使用CDN Chart.js作为后备方案")
        return "<script src=\"https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.js\"></script>"
    }

    // 中心标题构建已封装到 TitlebarIconManager
}

// MARK: - WKNavigationDelegate

extension ReportWindow: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("✅ 报告页面加载完成")
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("❌ 报告页面加载失败: \(error.localizedDescription)")
    }
}

// MARK: - WKUIDelegate (JS alert/confirm/prompt)
extension ReportWindow: WKUIDelegate {
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "提示"
        alert.informativeText = message
        alert.addButton(withTitle: "好的")
        alert.beginSheetModal(for: self) { _ in
            completionHandler()
        }
    }
}

// MARK: - WKScriptMessageHandler

extension ReportWindow: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "consoleLog":
            #if DEBUG
            print("📊 Report JS Log: \(message.body)")
            #endif
        case "consoleWarn":
            print("⚠️ Report JS Warn: \(message.body)")
        case "consoleError":
            print("❌ Report JS Error: \(message.body)")
        case "saveMood":
            if let dict = message.body as? [String: Any] {
                let level = dict["level"] as? Int
                let note = dict["note"] as? String
                StatisticsManager.shared.updateTodayMood(moodLevel: level, moodNote: note)
            } else {
                print("⚠️ saveMood payload 格式不正确: \(message.body)")
            }
        case "saveReportImage":
            captureReportSnapshotAndShare()
        default:
            break
        }
    }
}
