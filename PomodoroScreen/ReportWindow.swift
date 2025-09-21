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
    
    private func loadReportHTML(_ data: ReportData) {
        let htmlContent = generateReportHTML(data)
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }
    
    private func generateReportHTML(_ data: ReportData) -> String {
        // 尝试使用本地Chart.js文件
        if let chartJSPath = Bundle.main.path(forResource: "chart", ofType: "js") {
            do {
                let chartJSContent = try String(contentsOfFile: chartJSPath, encoding: .utf8)
                return buildReportHTML(data, chartJSScript: "<script>\(chartJSContent)</script>")
            } catch {
                print("⚠️ 无法读取Chart.js文件: \(error)")
            }
        } else {
            print("⚠️ 找不到Chart.js文件")
        }
        
        // 如果本地文件读取失败，使用CDN作为后备
        print("📡 使用CDN Chart.js作为后备方案")
        return buildReportHTML(data, chartJSScript: "<script src=\"https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.js\"></script>")
    }
    
    // 构建报告HTML的通用方法
    private func buildReportHTML(_ data: ReportData, chartJSScript: String) -> String {
        let jsonData = data.toJSONString() ?? "{}"
        
        return """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>今日工作报告</title>
            \(chartJSScript)
            <style>
                \(getReportCSS())
            </style>
        </head>
        <body>
            <div class="container">
                <header class="report-header">
                    <h1>📊 今日工作报告</h1>
                    <p class="report-date" id="reportDate"></p>
                </header>
                
                <div class="dashboard">
                    <!-- 核心指标卡片 -->
                    <div class="metrics-grid">
                        <div class="metric-card pomodoro-card">
                            <div class="metric-icon">🍅</div>
                            <div class="metric-content">
                                <h3 id="pomodoroCount">0</h3>
                                <p>完成番茄钟</p>
                            </div>
                        </div>
                        
                        <div class="metric-card work-time-card">
                            <div class="metric-icon">⏰</div>
                            <div class="metric-content">
                                <h3 id="workTime">0h 0m</h3>
                                <p>工作时间</p>
                            </div>
                        </div>
                        
                        <div class="metric-card break-time-card">
                            <div class="metric-icon">☕</div>
                            <div class="metric-content">
                                <h3 id="breakTime">0m</h3>
                                <p>休息时间</p>
                            </div>
                        </div>
                        
                        <div class="metric-card health-card">
                            <div class="metric-icon">💚</div>
                            <div class="metric-content">
                                <h3 id="healthScore">0</h3>
                                <p>健康评分</p>
                            </div>
                        </div>
                    </div>
                    
                    <!-- 评分仪表盘 -->
                    <div class="scores-section">
                        <h2>📈 综合评估</h2>
                        <div class="scores-grid">
                            <div class="score-item">
                                <canvas id="workIntensityChart" width="120" height="120"></canvas>
                                <p>工作强度</p>
                            </div>
                            <div class="score-item">
                                <canvas id="restAdequacyChart" width="120" height="120"></canvas>
                                <p>休息充足度</p>
                            </div>
                            <div class="score-item">
                                <canvas id="focusChart" width="120" height="120"></canvas>
                                <p>专注度</p>
                            </div>
                            <div class="score-item">
                                <canvas id="healthChart" width="120" height="120"></canvas>
                                <p>健康度</p>
                            </div>
                        </div>
                    </div>
                    
                    <!-- 详细统计 -->
                    <div class="details-section">
                        <h2>📋 详细统计</h2>
                        <div class="details-grid">
                            <div class="detail-item">
                                <span class="detail-label">短休息次数</span>
                                <span class="detail-value" id="shortBreakCount">0</span>
                            </div>
                            <div class="detail-item">
                                <span class="detail-label">长休息次数</span>
                                <span class="detail-value" id="longBreakCount">0</span>
                            </div>
                            <div class="detail-item">
                                <span class="detail-label">取消休息次数</span>
                                <span class="detail-value" id="cancelledBreakCount">0</span>
                            </div>
                            <div class="detail-item">
                                <span class="detail-label">息屏次数</span>
                                <span class="detail-value" id="screenLockCount">0</span>
                            </div>
                            <div class="detail-item">
                                <span class="detail-label">屏保次数</span>
                                <span class="detail-value" id="screensaverCount">0</span>
                            </div>
                            <div class="detail-item">
                                <span class="detail-label">熬夜次数</span>
                                <span class="detail-value" id="stayUpLateCount">0</span>
                            </div>
                        </div>
                    </div>
                    
                    <!-- 周趋势图表 -->
                    <div class="trends-section">
                        <h2>📊 本周趋势</h2>
                        <div class="chart-container">
                            <canvas id="weeklyTrendChart" width="800" height="300"></canvas>
                        </div>
                    </div>
                    
                    <!-- 健康建议 -->
                    <div class="recommendations-section">
                        <h2>💡 健康建议</h2>
                        <div id="recommendationsList" class="recommendations-list">
                        </div>
                    </div>
                </div>
            </div>
            
            <script>
                // 报告数据
                const reportData = \(jsonData);
                
                \(getReportJavaScript())
            </script>
        </body>
        </html>
        """
    }
    
    private func getReportCSS() -> String {
        return """
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            background-attachment: fixed;
            color: #333;
            margin: 0;
            padding: 0;
            overflow-x: hidden;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        
        .report-header {
            text-align: center;
            margin-bottom: 30px;
            color: white;
        }
        
        .report-header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
            text-shadow: 0 2px 4px rgba(0,0,0,0.3);
        }
        
        .report-date {
            font-size: 1.2em;
            opacity: 0.9;
        }
        
        .dashboard {
            background: white;
            border-radius: 20px;
            padding: 30px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }
        
        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 40px;
        }
        
        .metric-card {
            background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
            border-radius: 15px;
            padding: 25px;
            color: white;
            display: flex;
            align-items: center;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
            transition: transform 0.3s ease;
        }
        
        .metric-card:hover {
            transform: translateY(-5px);
        }
        
        .pomodoro-card {
            background: linear-gradient(135deg, #ff9a9e 0%, #fecfef 100%);
        }
        
        .work-time-card {
            background: linear-gradient(135deg, #a8edea 0%, #fed6e3 100%);
        }
        
        .break-time-card {
            background: linear-gradient(135deg, #ffecd2 0%, #fcb69f 100%);
        }
        
        .health-card {
            background: linear-gradient(135deg, #a8ff78 0%, #78ffd6 100%);
        }
        
        .metric-icon {
            font-size: 3em;
            margin-right: 20px;
        }
        
        .metric-content h3 {
            font-size: 2.2em;
            font-weight: bold;
            margin-bottom: 5px;
        }
        
        .metric-content p {
            font-size: 1.1em;
            opacity: 0.9;
        }
        
        .scores-section {
            margin-bottom: 40px;
        }
        
        .scores-section h2 {
            margin-bottom: 20px;
            color: #333;
        }
        
        .scores-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 30px;
            text-align: center;
        }
        
        .score-item p {
            margin-top: 10px;
            font-weight: 600;
            color: #666;
        }
        
        .details-section {
            margin-bottom: 40px;
        }
        
        .details-section h2 {
            margin-bottom: 20px;
            color: #333;
        }
        
        .details-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
        }
        
        .detail-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 15px 20px;
            background: #f8f9fa;
            border-radius: 10px;
            border-left: 4px solid #667eea;
        }
        
        .detail-label {
            font-weight: 500;
            color: #666;
        }
        
        .detail-value {
            font-weight: bold;
            color: #333;
            font-size: 1.2em;
        }
        
        .trends-section {
            margin-bottom: 40px;
        }
        
        .trends-section h2 {
            margin-bottom: 20px;
            color: #333;
        }
        
        .chart-container {
            background: #f8f9fa;
            border-radius: 15px;
            padding: 20px;
            height: 350px;
            position: relative;
            overflow: hidden;
        }
        
        .chart-container canvas {
            max-height: 300px !important;
            width: 100% !important;
            height: 300px !important;
        }
        
        .recommendations-section h2 {
            margin-bottom: 20px;
            color: #333;
        }
        
        .recommendations-list {
            display: flex;
            flex-direction: column;
            gap: 15px;
        }
        
        .recommendation-item {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 15px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
        }
        
        .recommendation-item::before {
            content: '💡';
            margin-right: 10px;
        }
        """
    }
    
    private func getReportJavaScript() -> String {
        return """
        // 防止重复初始化的标志
        var reportInitialized = false;
        
        // 初始化报告
        function initializeReport() {
            if (reportInitialized) {
                console.log('Report already initialized, skipping...');
                return;
            }
            
            // 检查Chart.js是否加载
            if (typeof Chart === 'undefined') {
                console.error('Chart.js not loaded, retrying in 500ms...');
                setTimeout(initializeReport, 500);
                return;
            }
            
            try {
                console.log('Starting report initialization...');
                console.log('Chart.js version:', Chart.version);
                console.log('Report data:', reportData);
                
                updateBasicMetrics();
                createScoreCharts();
                createWeeklyTrendChart();
                showRecommendations();
                reportInitialized = true;
                console.log('Report initialized successfully');
            } catch (error) {
                console.error('Error initializing report:', error);
                console.error('Stack trace:', error.stack);
            }
        }
        
        // 更新基本指标
        function updateBasicMetrics() {
            const daily = reportData.daily;
            
            // 更新日期
            document.getElementById('reportDate').textContent = 
                new Date(daily.date).toLocaleDateString('zh-CN', {
                    year: 'numeric',
                    month: 'long',
                    day: 'numeric'
                });
            
            // 更新核心指标
            document.getElementById('pomodoroCount').textContent = daily.completedPomodoros;
            
            const workHours = Math.floor(daily.totalWorkTime / 3600);
            const workMinutes = Math.floor((daily.totalWorkTime % 3600) / 60);
            document.getElementById('workTime').textContent = workHours + 'h ' + workMinutes + 'm';
            
            const breakMinutes = Math.floor(daily.totalBreakTime / 60);
            document.getElementById('breakTime').textContent = breakMinutes + 'm';
            
            document.getElementById('healthScore').textContent = Math.round(daily.healthScore);
            
            // 更新详细统计
            document.getElementById('shortBreakCount').textContent = daily.shortBreakCount;
            document.getElementById('longBreakCount').textContent = daily.longBreakCount;
            document.getElementById('cancelledBreakCount').textContent = daily.cancelledBreakCount;
            document.getElementById('screenLockCount').textContent = daily.screenLockCount;
            document.getElementById('screensaverCount').textContent = daily.screensaverCount;
            document.getElementById('stayUpLateCount').textContent = daily.stayUpLateCount;
        }
        
        // 创建评分圆环图
        function createScoreCharts() {
            const daily = reportData.daily;
            
            if (typeof Chart === 'undefined') {
                console.warn('Chart.js not available, using fallback display');
                createFallbackScoreDisplay();
                return;
            }
            
            createDoughnutChart('workIntensityChart', daily.workIntensityScore, '工作强度', '#ff6b6b');
            createDoughnutChart('restAdequacyChart', daily.restAdequacyScore, '休息充足度', '#4ecdc4');
            createDoughnutChart('focusChart', daily.focusScore, '专注度', '#45b7d1');
            createDoughnutChart('healthChart', daily.healthScore, '健康度', '#96ceb4');
        }
        
        // Chart.js不可用时的备用显示
        function createFallbackScoreDisplay() {
            const daily = reportData.daily;
            const scores = [
                { id: 'workIntensityChart', score: daily.workIntensityScore, label: '工作强度' },
                { id: 'restAdequacyChart', score: daily.restAdequacyScore, label: '休息充足度' },
                { id: 'focusChart', score: daily.focusScore, label: '专注度' },
                { id: 'healthChart', score: daily.healthScore, label: '健康度' }
            ];
            
            scores.forEach(item => {
                const canvas = document.getElementById(item.id);
                if (canvas) {
                    const ctx = canvas.getContext('2d');
                    // 简单的文本显示
                    ctx.font = '24px Arial';
                    ctx.textAlign = 'center';
                    ctx.fillStyle = '#333';
                    ctx.fillText(Math.round(item.score), canvas.width/2, canvas.height/2);
                }
            });
        }
        
        function createDoughnutChart(canvasId, score, label, color) {
            const ctx = document.getElementById(canvasId).getContext('2d');
            
            // 销毁已存在的图表
            if (window[canvasId + '_chart'] && typeof window[canvasId + '_chart'].destroy === 'function') {
                window[canvasId + '_chart'].destroy();
            }
            
            window[canvasId + '_chart'] = new Chart(ctx, {
                type: 'doughnut',
                data: {
                    datasets: [{
                        data: [score, 100 - score],
                        backgroundColor: [color, '#e0e0e0'],
                        borderWidth: 0
                    }]
                },
                options: {
                    responsive: false,
                    maintainAspectRatio: true,
                    cutout: '70%',
                    plugins: {
                        legend: {
                            display: false
                        },
                        tooltip: {
                            enabled: false
                        }
                    },
                    elements: {
                        arc: {
                            borderWidth: 0
                        }
                    },
                    animation: {
                        duration: 0
                    }
                },
                plugins: [{
                    afterDraw: function(chart) {
                        const ctx = chart.ctx;
                        ctx.save();
                        const centerX = chart.chartArea.left + (chart.chartArea.right - chart.chartArea.left) / 2;
                        const centerY = chart.chartArea.top + (chart.chartArea.bottom - chart.chartArea.top) / 2;
                        ctx.textAlign = 'center';
                        ctx.textBaseline = 'middle';
                        ctx.font = 'bold 16px Arial';
                        ctx.fillStyle = color;
                        ctx.fillText(Math.round(score), centerX, centerY);
                        ctx.restore();
                    }
                }]
            });
        }
        
        // 创建周趋势图
        function createWeeklyTrendChart() {
            console.log('Creating weekly trend chart...');
            
            if (typeof Chart === 'undefined') {
                console.warn('Chart.js not available, showing fallback message');
                const canvas = document.getElementById('weeklyTrendChart');
                if (canvas) {
                    const ctx = canvas.getContext('2d');
                    ctx.font = '16px Arial';
                    ctx.textAlign = 'center';
                    ctx.fillStyle = '#666';
                    ctx.fillText('图表加载中...', canvas.width/2, canvas.height/2);
                }
                return;
            }
            
            const weekly = reportData.weekly;
            console.log('Weekly data:', weekly);
            
            if (!weekly || !weekly.dailyTrend || weekly.dailyTrend.length === 0) {
                console.warn('No weekly trend data available, using mock data');
                // 使用模拟数据
                const mockWeekly = {
                    dailyTrend: [
                        { date: new Date().toISOString(), pomodoros: 0, workIntensity: 0, healthScore: 100 },
                        { date: new Date().toISOString(), pomodoros: 0, workIntensity: 0, healthScore: 100 },
                        { date: new Date().toISOString(), pomodoros: 0, workIntensity: 0, healthScore: 100 },
                        { date: new Date().toISOString(), pomodoros: 0, workIntensity: 0, healthScore: 100 },
                        { date: new Date().toISOString(), pomodoros: 0, workIntensity: 0, healthScore: 100 },
                        { date: new Date().toISOString(), pomodoros: 0, workIntensity: 0, healthScore: 100 },
                        { date: new Date().toISOString(), pomodoros: 0, workIntensity: 0, healthScore: 100 }
                    ]
                };
                createWeeklyTrendChartWithData(mockWeekly);
                return;
            }
            
            createWeeklyTrendChartWithData(weekly);
        }
        
        function createWeeklyTrendChartWithData(weekly) {
            const ctx = document.getElementById('weeklyTrendChart').getContext('2d');
            
            // 销毁已存在的图表
            if (window.weeklyTrendChart && typeof window.weeklyTrendChart.destroy === 'function') {
                window.weeklyTrendChart.destroy();
            }
            
            const labels = weekly.dailyTrend.map((day, index) => {
                const date = new Date();
                date.setDate(date.getDate() - (6 - index)); // 生成过去7天的日期
                return date.toLocaleDateString('zh-CN', { weekday: 'short' });
            });
            console.log('Chart labels:', labels);
            
            window.weeklyTrendChart = new Chart(ctx, {
                type: 'line',
                data: {
                    labels: labels,
                    datasets: [
                        {
                            label: '番茄钟数量',
                            data: weekly.dailyTrend.map(day => day.pomodoros),
                            borderColor: '#ff6b6b',
                            backgroundColor: 'rgba(255, 107, 107, 0.1)',
                            tension: 0.4,
                            yAxisID: 'y'
                        },
                        {
                            label: '工作强度',
                            data: weekly.dailyTrend.map(day => day.workIntensity),
                            borderColor: '#4ecdc4',
                            backgroundColor: 'rgba(78, 205, 196, 0.1)',
                            tension: 0.4,
                            yAxisID: 'y1'
                        },
                        {
                            label: '健康度',
                            data: weekly.dailyTrend.map(day => day.healthScore),
                            borderColor: '#96ceb4',
                            backgroundColor: 'rgba(150, 206, 180, 0.1)',
                            tension: 0.4,
                            yAxisID: 'y1'
                        }
                    ]
                },
                options: {
                    responsive: false,
                    maintainAspectRatio: false,
                    interaction: {
                        mode: 'index',
                        intersect: false,
                    },
                    animation: {
                        duration: 0
                    },
                    scales: {
                        x: {
                            display: true,
                            title: {
                                display: true,
                                text: '日期'
                            }
                        },
                        y: {
                            type: 'linear',
                            display: true,
                            position: 'left',
                            title: {
                                display: true,
                                text: '番茄钟数量'
                            },
                            min: 0
                        },
                        y1: {
                            type: 'linear',
                            display: true,
                            position: 'right',
                            title: {
                                display: true,
                                text: '评分'
                            },
                            min: 0,
                            max: 100,
                            grid: {
                                drawOnChartArea: false,
                            },
                        }
                    },
                    plugins: {
                        legend: {
                            position: 'top',
                        },
                        title: {
                            display: true,
                            text: '本周工作趋势'
                        }
                    }
                }
            });
        }
        
        // 显示建议
        function showRecommendations() {
            console.log('Showing recommendations...');
            const recommendations = generateRecommendations();
            console.log('Generated recommendations:', recommendations);
            
            const container = document.getElementById('recommendationsList');
            if (!container) {
                console.error('Recommendations container not found');
                return;
            }
            
            // 清空现有内容，防止重复添加
            container.innerHTML = '';
            
            if (recommendations.length === 0) {
                console.warn('No recommendations generated');
                return;
            }
            
            recommendations.forEach(recommendation => {
                const item = document.createElement('div');
                item.className = 'recommendation-item';
                item.textContent = recommendation;
                container.appendChild(item);
            });
            
            console.log('Recommendations displayed successfully');
        }
        
        // 生成建议
        function generateRecommendations() {
            const daily = reportData.daily;
            const recommendations = [];
            
            console.log('Generating recommendations for daily data:', daily);
            
            if (!daily) {
                console.warn('No daily data available for recommendations');
                return ['📊 欢迎使用番茄钟工作报告！', '🍅 开始使用番茄钟来记录您的工作数据'];
            }
            
            if (daily.workIntensityScore < 50) {
                recommendations.push('💪 建议增加番茄钟数量，提高工作效率');
            }
            
            if (daily.restAdequacyScore < 60) {
                recommendations.push('☕ 休息时间不足，建议严格执行休息计划');
            }
            
            if (daily.cancelledBreakCount > 2) {
                recommendations.push('🎯 频繁取消休息会影响专注度，建议坚持休息');
            }
            
            if (daily.stayUpLateCount > 0) {
                recommendations.push('🌙 检测到熬夜行为，建议调整作息时间');
            }
            
            if (daily.healthScore >= 80) {
                recommendations.push('🎉 今日工作状态良好，继续保持！');
            }
            
            if (daily.focusScore >= 80) {
                recommendations.push('🏆 专注度很高，工作效率优秀！');
            }
            
            if (recommendations.length === 0) {
                if (daily.completedPomodoros === 0) {
                    recommendations.push('🚀 开始您的第一个番茄钟，建立高效工作习惯！');
                    recommendations.push('⏰ 建议设置25分钟专注工作，5分钟休息的节奏');
                } else {
                    recommendations.push('👍 工作状态正常，继续保持良好的工作节奏');
                }
            }
            
            console.log('Generated recommendations:', recommendations);
            return recommendations;
        }
        
        // 页面加载完成后初始化
        document.addEventListener('DOMContentLoaded', function() {
            console.log('DOM loaded, starting initialization...');
            initializeReport();
        });
        
        // 如果Chart.js加载失败，提供备用初始化
        window.addEventListener('load', function() {
            console.log('Window loaded');
            if (!reportInitialized) {
                console.log('Report not initialized yet, retrying...');
                setTimeout(initializeReport, 1000);
            }
        });
        """
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
            print("📊 Report JS Log: \(message.body)")
        case "consoleWarn":
            print("⚠️ Report JS Warn: \(message.body)")
        case "consoleError":
            print("❌ Report JS Error: \(message.body)")
        default:
            break
        }
    }
}
