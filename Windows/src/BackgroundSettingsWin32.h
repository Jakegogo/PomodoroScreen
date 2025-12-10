#pragma once

#include <string>
#include <vector>

namespace pomodoro {

    // 与 macOS 端 BackgroundFile 结构对应的简化版本
    enum class BackgroundType {
        Image,
        Video
    };

    struct BackgroundFileWin32 {
        std::wstring path;        // 完整文件路径
        BackgroundType type;      // 文件类型（图片 / 视频）
        std::wstring name;        // 显示名称（文件名）
        double playbackRate;      // 播放速率（仅对视频有效，默认 1.0）
    };

    // 本地配置存储：使用 JSON 文件保存背景列表，存放在用户配置目录中
    class BackgroundSettingsWin32 {
    public:
        BackgroundSettingsWin32() = default;

        // 返回默认配置文件路径（用户空间），例如：%APPDATA%\PomodoroScreen\backgrounds.json
        static std::wstring DefaultConfigPath();

        // 从给定路径加载配置（如果文件不存在则返回 false，但不会视为错误）
        bool loadFromFile(const std::wstring& filePath);

        // 将当前配置保存到给定路径
        bool saveToFile(const std::wstring& filePath) const;

        const std::vector<BackgroundFileWin32>& files() const { return files_; }
        std::vector<BackgroundFileWin32>& files() { return files_; }

    private:
        std::vector<BackgroundFileWin32> files_{};
    };

} // namespace pomodoro



