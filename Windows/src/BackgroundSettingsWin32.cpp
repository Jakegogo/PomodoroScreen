#include "BackgroundSettingsWin32.h"

#include <windows.h>
#include <shlobj.h>
#include <fstream>
#include <sstream>

#pragma comment(lib, "Shell32.lib")

namespace {

    std::wstring ExtractFileName(const std::wstring& path) {
        auto pos = path.find_last_of(L"\\/"); // 同时支持 / 和 '\\'
        if (pos == std::wstring::npos) return path;
        return path.substr(pos + 1);
    }

    // 非严格 JSON 转义，仅处理我们会用到的几个字符
    std::wstring EscapeJsonString(const std::wstring& input) {
        std::wstring out;
        out.reserve(input.size());
        for (wchar_t ch : input) {
            switch (ch) {
            case L'\\': out += L"\\\\"; break;
            case L'"':  out += L"\\\""; break;
            case L'\n': out += L"\\n";  break;
            case L'\r': out += L"\\r";  break;
            case L'\t': out += L"\\t";  break;
            default:
                out.push_back(ch);
                break;
            }
        }
        return out;
    }

    std::wstring UnescapeJsonString(const std::wstring& input) {
        std::wstring out;
        out.reserve(input.size());
        for (std::size_t i = 0; i < input.size(); ++i) {
            wchar_t ch = input[i];
            if (ch == L'\\' && i + 1 < input.size()) {
                wchar_t next = input[++i];
                switch (next) {
                case L'\\': out.push_back(L'\\'); break;
                case L'"':  out.push_back(L'"');  break;
                case L'n':  out.push_back(L'\n'); break;
                case L'r':  out.push_back(L'\r'); break;
                case L't':  out.push_back(L'\t'); break;
                default:
                    out.push_back(next);
                    break;
                }
            } else {
                out.push_back(ch);
            }
        }
        return out;
    }

    // 在 JSON 对象字符串中提取形如 "key": "value" 的字符串值
    bool ExtractJsonStringField(const std::wstring& obj, const std::wstring& key, std::wstring& outValue) {
        std::wstring pattern = L"\"" + key + L"\"";
        auto keyPos = obj.find(pattern);
        if (keyPos == std::wstring::npos) return false;

        auto colonPos = obj.find(L':', keyPos + pattern.size());
        if (colonPos == std::wstring::npos) return false;

        auto quoteStart = obj.find(L'"', colonPos);
        if (quoteStart == std::wstring::npos) return false;

        std::wstring raw;
        for (std::size_t i = quoteStart + 1; i < obj.size(); ++i) {
            wchar_t ch = obj[i];
            if (ch == L'\\' && i + 1 < obj.size()) {
                raw.push_back(ch);
                raw.push_back(obj[i + 1]);
                ++i;
            } else if (ch == L'"') {
                break;
            } else {
                raw.push_back(ch);
            }
        }

        outValue = UnescapeJsonString(raw);
        return true;
    }

    // 在 JSON 对象字符串中提取形如 "key": 1.23 的数字值
    bool ExtractJsonDoubleField(const std::wstring& obj, const std::wstring& key, double& outValue) {
        std::wstring pattern = L"\"" + key + L"\"";
        auto keyPos = obj.find(pattern);
        if (keyPos == std::wstring::npos) return false;

        auto colonPos = obj.find(L':', keyPos + pattern.size());
        if (colonPos == std::wstring::npos) return false;

        auto start = obj.find_first_of(L"-0123456789", colonPos + 1);
        if (start == std::wstring::npos) return false;

        auto end = start;
        while (end < obj.size() && (iswdigit(obj[end]) || obj[end] == L'.')) {
            ++end;
        }

        std::wstring numStr = obj.substr(start, end - start);
        wchar_t* endPtr = nullptr;
        double value = std::wcstod(numStr.c_str(), &endPtr);
        if (endPtr == numStr.c_str()) {
            return false;
        }
        outValue = value;
        return true;
    }

    // 在 JSON 文本中提取形如 "key": 123 的整数值（非严格解析，满足本项目配置文件结构即可）
    bool ExtractJsonIntFieldFromRoot(const std::wstring& json, const std::wstring& key, int& outValue) {
        std::wstring pattern = L"\"" + key + L"\"";
        auto keyPos = json.find(pattern);
        if (keyPos == std::wstring::npos) return false;

        auto colonPos = json.find(L':', keyPos + pattern.size());
        if (colonPos == std::wstring::npos) return false;

        auto start = json.find_first_of(L"-0123456789", colonPos + 1);
        if (start == std::wstring::npos) return false;

        auto end = start;
        while (end < json.size() && iswdigit(json[end])) {
            ++end;
        }

        std::wstring numStr = json.substr(start, end - start);
        wchar_t* endPtr = nullptr;
        long value = std::wcstol(numStr.c_str(), &endPtr, 10);
        if (endPtr == numStr.c_str()) return false;

        outValue = static_cast<int>(value);
        return true;
    }

    // 在 JSON 文本中提取形如 "key": "value" 的字符串值（root 层）。
    bool ExtractJsonStringFieldFromRoot(const std::wstring& json, const std::wstring& key, std::wstring& outValue) {
        std::wstring pattern = L"\"" + key + L"\"";
        auto keyPos = json.find(pattern);
        if (keyPos == std::wstring::npos) return false;

        auto colonPos = json.find(L':', keyPos + pattern.size());
        if (colonPos == std::wstring::npos) return false;

        auto quoteStart = json.find(L'"', colonPos);
        if (quoteStart == std::wstring::npos) return false;

        std::wstring raw;
        for (std::size_t i = quoteStart + 1; i < json.size(); ++i) {
            wchar_t ch = json[i];
            if (ch == L'\\' && i + 1 < json.size()) {
                raw.push_back(ch);
                raw.push_back(json[i + 1]);
                ++i;
            } else if (ch == L'"') {
                break;
            } else {
                raw.push_back(ch);
            }
        }

        outValue = UnescapeJsonString(raw);
        return true;
    }

} // namespace

namespace pomodoro {

    std::wstring BackgroundSettingsWin32::DefaultConfigPath() {
        wchar_t appDataPath[MAX_PATH] = { 0 };
        if (SUCCEEDED(SHGetFolderPathW(nullptr, CSIDL_APPDATA, nullptr, SHGFP_TYPE_CURRENT, appDataPath))) {
            std::wstring dir = std::wstring(appDataPath) + L"\\PomodoroScreen";
            CreateDirectoryW(dir.c_str(), nullptr); // 已存在时会失败，但忽略错误
            return dir + L"\\backgrounds.json";
        }
        // 回退到当前工作目录
        return L"backgrounds.json";
    }

    bool BackgroundSettingsWin32::loadFromFile(const std::wstring& filePath) {
        files_.clear();
        overlayMessage_.clear();

        std::wifstream in(filePath);
        if (!in.is_open()) {
            // 文件不存在时视为“无配置”，由调用方决定是否保存新配置
            return false;
        }
        in.imbue(std::locale("", std::locale::all)); // 使用系统本地编码，支持中文路径

        std::wstringstream buffer;
        buffer << in.rdbuf();
        const std::wstring json = buffer.str();

        // 查找 "backgrounds": [ ... ] 段
        const std::wstring key = L"\"backgrounds\"";
        auto keyPos = json.find(key);
        if (keyPos == std::wstring::npos) {
            return false;
        }

        auto arrayStart = json.find(L'[', keyPos);
        if (arrayStart == std::wstring::npos) {
            return false;
        }
        auto arrayEnd = json.find(L']', arrayStart);
        if (arrayEnd == std::wstring::npos || arrayEnd <= arrayStart) {
            return false;
        }

        std::wstring arrayBody = json.substr(arrayStart + 1, arrayEnd - arrayStart - 1);

        std::size_t pos = 0;
        while (true) {
            auto objStart = arrayBody.find(L'{', pos);
            if (objStart == std::wstring::npos) break;
            auto objEnd = arrayBody.find(L'}', objStart);
            if (objEnd == std::wstring::npos) break;

            std::wstring obj = arrayBody.substr(objStart, objEnd - objStart + 1);
            pos = objEnd + 1;

            std::wstring path, typeStr, name;
            double rate = 1.0;

            if (!ExtractJsonStringField(obj, L"path", path)) continue;
            if (!ExtractJsonStringField(obj, L"type", typeStr)) continue;
            if (!ExtractJsonStringField(obj, L"name", name)) {
                name = ExtractFileName(path);
            }
            ExtractJsonDoubleField(obj, L"playbackRate", rate);
            if (rate <= 0.0) rate = 1.0;

            BackgroundType type = BackgroundType::Image;
            if (typeStr == L"video") {
                type = BackgroundType::Video;
            }

            files_.push_back(BackgroundFileWin32{ path, type, name, rate });
        }

        // 解析可选的 autoStartNextPomodoroAfterRest 字段
        auto parseBoolField = [&](const std::wstring& key, bool& outValue) {
            std::wstring boolKey = L"\"" + key + L"\"";
            auto boolPos = json.find(boolKey);
            if (boolPos == std::wstring::npos) return false;
            auto colonPos = json.find(L':', boolPos + boolKey.size());
            if (colonPos == std::wstring::npos) return false;
            auto valueStart = json.find_first_not_of(L" \t\r\n", colonPos + 1);
            if (valueStart == std::wstring::npos) return false;
            if (json.compare(valueStart, 4, L"true") == 0) {
                outValue = true;
                return true;
            }
            if (json.compare(valueStart, 5, L"false") == 0) {
                outValue = false;
                return true;
            }
            return false;
        };

        parseBoolField(L"autoStartNextPomodoroAfterRest", autoStartNextPomodoroAfterRest_);

        // 解析可选的 pomodoroMinutes 字段
        int pomodoroMinutes = pomodoroMinutes_;
        if (ExtractJsonIntFieldFromRoot(json, L"pomodoroMinutes", pomodoroMinutes)) {
            if (pomodoroMinutes < 5) pomodoroMinutes = 5;
            if (pomodoroMinutes > 120) pomodoroMinutes = 120;
            pomodoroMinutes_ = pomodoroMinutes;
        }

        // 解析可选的 overlayMessage 字段
        ExtractJsonStringFieldFromRoot(json, L"overlayMessage", overlayMessage_);

        return true;
    }

    bool BackgroundSettingsWin32::saveToFile(const std::wstring& filePath) const {
        std::wofstream out(filePath, std::ios::trunc);
        if (!out.is_open()) {
            return false;
        }
        out.imbue(std::locale("", std::locale::all));

        out << L"{\n  \"backgrounds\": [\n";

        for (std::size_t i = 0; i < files_.size(); ++i) {
            const auto& file = files_[i];
            std::wstring typeStr = (file.type == BackgroundType::Image) ? L"image" : L"video";

            out << L"    { "
                << L"\"path\": \"" << EscapeJsonString(file.path) << L"\", "
                << L"\"type\": \"" << typeStr << L"\", "
                << L"\"name\": \"" << EscapeJsonString(file.name) << L"\", "
                << L"\"playbackRate\": " << file.playbackRate
                << L" }";

            if (i + 1 < files_.size()) {
                out << L",";
            }
            out << L"\n";
        }

        out << L"  ],\n";
        out << L"  \"pomodoroMinutes\": " << pomodoroMinutes_ << L",\n";
        out << L"  \"autoStartNextPomodoroAfterRest\": " << (autoStartNextPomodoroAfterRest_ ? L"true" : L"false") << L",\n";
        out << L"  \"overlayMessage\": \"" << EscapeJsonString(overlayMessage_) << L"\"\n";
        out << L"}\n";

        return true;
    }

} // namespace pomodoro


