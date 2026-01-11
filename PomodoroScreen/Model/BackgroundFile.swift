//
//  BackgroundFile.swift
//  PomodoroScreen
//
//  Created by jake on 2026/1/10.
//

// 背景文件数据结构
struct BackgroundFile: Codable {
    let path: String // 文件路径
    let type: BackgroundType // 文件类型
    let name: String // 显示名称
    let playbackRate: Double // 视频播放速率（0.1-8.0，默认1.0）
    
    enum BackgroundType: String, Codable, CaseIterable {
        case image = "image"
        case video = "video"
        
        var displayName: String {
            switch self {
            case .image: return "图片"
            case .video: return "视频"
            }
        }
    }
}
