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
        self.title = "📊 今日工作报告"
        self.center()
        self.isReleasedWhenClosed = false
        self.minSize = NSSize(width: 800, height: 600)
        
        // 设置窗口样式
        self.titlebarAppearsTransparent = false
        self.backgroundColor = NSColor.windowBackgroundColor
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
            webView.loadHTMLString(htmlContent, baseURL: nil)
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
        default:
            break
        }
    }
}
