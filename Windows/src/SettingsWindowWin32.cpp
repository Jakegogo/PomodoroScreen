#include "SettingsWindowWin32.h"

#include <commdlg.h>

namespace {

    const wchar_t* kSettingsWindowClassName = L"PomodoroSettingsWindowClass";

    // 控件 ID
    constexpr int kIdListBox = 1001;
    constexpr int kIdAddImageButton = 1002;
    constexpr int kIdAddVideoButton = 1003;
    constexpr int kIdRemoveButton = 1004;
    constexpr int kIdMoveUpButton = 1005;
    constexpr int kIdMoveDownButton = 1006;
    constexpr int kIdAutoHideCheckbox = 1007;
    constexpr int kIdTabBehavior = 1101;
    constexpr int kIdTabBackground = 1102;

    ATOM RegisterSettingsWindowClass(HINSTANCE hInstance) {
        static ATOM s_atom = 0;
        if (s_atom != 0) return s_atom;

        WNDCLASSEXW wc{};
        wc.cbSize = sizeof(WNDCLASSEXW);
        wc.style = CS_HREDRAW | CS_VREDRAW;
        wc.lpfnWndProc = pomodoro::SettingsWindowWin32::WndProc;
        wc.cbClsExtra = 0;
        wc.cbWndExtra = sizeof(LONG_PTR);
        wc.hInstance = hInstance;
        wc.hIcon = nullptr;
        wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
        wc.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
        wc.lpszMenuName = nullptr;
        wc.lpszClassName = kSettingsWindowClassName;
        wc.hIconSm = nullptr;

        s_atom = RegisterClassExW(&wc);
        return s_atom;
    }

    std::wstring ExtractFileName(const std::wstring& path) {
        auto pos = path.find_last_of(L"\\/");
        if (pos == std::wstring::npos) return path;
        return path.substr(pos + 1);
    }

} // namespace

namespace pomodoro {

    SettingsWindowWin32::SettingsWindowWin32(HINSTANCE hInstance, BackgroundSettingsWin32& settings)
        : hInstance_(hInstance)
        , settings_(settings) {
    }

    void SettingsWindowWin32::show() {
        if (!RegisterSettingsWindowClass(hInstance_)) {
            return;
        }

        if (!hwnd_) {
            // 创建一个简单窗口，大小和 mac 设置窗口接近
            hwnd_ = CreateWindowExW(
                0,
                kSettingsWindowClassName,
                L"\u756a\u8304\u949f\u8bbe\u7f6e - \u80cc\u666f", // "番茄钟设置 - 背景"
                WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX,
                CW_USEDEFAULT,
                CW_USEDEFAULT,
                540,
                420,
                nullptr,
                nullptr,
                hInstance_,
                this // lpParam -> WM_NCCREATE
            );
        }

        if (!hwnd_) return;

        ShowWindow(hwnd_, SW_SHOWNORMAL);
        UpdateWindow(hwnd_);
    }

    LRESULT CALLBACK SettingsWindowWin32::WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
        SettingsWindowWin32* self = nullptr;

        if (msg == WM_NCCREATE) {
            auto* cs = reinterpret_cast<CREATESTRUCTW*>(lParam);
            self = static_cast<SettingsWindowWin32*>(cs->lpCreateParams);
            SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
        } else {
            self = reinterpret_cast<SettingsWindowWin32*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
        }

        if (self) {
            LRESULT result = self->handleMessage(hwnd, msg, wParam, lParam);
            if (msg == WM_NCDESTROY) {
                // 清空句柄，避免悬挂引用
                self->hwnd_ = nullptr;
            }
            return result;
        }

        return DefWindowProcW(hwnd, msg, wParam, lParam);
    }

    LRESULT SettingsWindowWin32::handleMessage(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
        switch (msg) {
        case WM_CREATE:
            onCreate(hwnd);
            return 0;
        case WM_COMMAND: {
            const int id = LOWORD(wParam);
            const int code = HIWORD(wParam);
            if (code == BN_CLICKED) {
                switch (id) {
                case kIdAddImageButton:
                    onAddImage();
                    break;
                case kIdAddVideoButton:
                    onAddVideo();
                    break;
                case kIdRemoveButton:
                    onRemove();
                    break;
                case kIdMoveUpButton:
                    onMoveUp();
                    break;
                case kIdMoveDownButton:
                    onMoveDown();
                    break;
                case kIdAutoHideCheckbox:
                    onAutoHideChanged();
                    break;
                case kIdTabBehavior:
                    switchToTab(0);
                    break;
                case kIdTabBackground:
                    switchToTab(1);
                    break;
                default:
                    break;
                }
            }
            return 0;
        }
        case WM_CLOSE:
            DestroyWindow(hwnd);
            return 0;
        case WM_DESTROY:
            onDestroy();
            return 0;
        default:
            break;
        }

        return DefWindowProcW(hwnd, msg, wParam, lParam);
    }

    void SettingsWindowWin32::onCreate(HWND hwnd) {
        // 顶部“标签”按钮（行为 / 背景）
        behaviorTabButton_ = CreateWindowExW(
            0,
            L"BUTTON",
            L"\u884c\u4e3a\u8bbe\u7f6e", // "行为设置"
            WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            20,
            10,
            120,
            24,
            hwnd,
            reinterpret_cast<HMENU>(static_cast<INT_PTR>(kIdTabBehavior)),
            hInstance_,
            nullptr
        );

        backgroundTabButton_ = CreateWindowExW(
            0,
            L"BUTTON",
            L"\u80cc\u666f\u8bbe\u7f6e", // "背景设置"
            WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            150,
            10,
            120,
            24,
            hwnd,
            reinterpret_cast<HMENU>(static_cast<INT_PTR>(kIdTabBackground)),
            hInstance_,
            nullptr
        );

        // 背景设置页控件：左侧列表框
        listBox_ = CreateWindowExW(
            WS_EX_CLIENTEDGE,
            L"LISTBOX",
            nullptr,
            WS_CHILD | WS_VISIBLE | LBS_NOTIFY | WS_VSCROLL | WS_BORDER,
            20,
            50,
            320,
            320,
            hwnd,
            reinterpret_cast<HMENU>(static_cast<INT_PTR>(kIdListBox)),
            hInstance_,
            nullptr
        );

        // 右侧按钮区域起始位置（背景设置标签页）
        const int btnX = 360;
        int btnY = 70;
        const int btnWidth = 120;
        const int btnHeight = 28;
        const int btnGap = 10;

        addImageButton_ = CreateWindowExW(
            0,
            L"BUTTON",
            L"\u6dfb\u52a0\u56fe\u7247...", // "添加图片..."
            WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            btnX,
            btnY,
            btnWidth,
            btnHeight,
            hwnd,
            reinterpret_cast<HMENU>(static_cast<INT_PTR>(kIdAddImageButton)),
            hInstance_,
            nullptr
        );
        btnY += btnHeight + btnGap;

        addVideoButton_ = CreateWindowExW(
            0,
            L"BUTTON",
            L"\u6dfb\u52a0\u89c6\u9891...", // "添加视频..."
            WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            btnX,
            btnY,
            btnWidth,
            btnHeight,
            hwnd,
            reinterpret_cast<HMENU>(static_cast<INT_PTR>(kIdAddVideoButton)),
            hInstance_,
            nullptr
        );
        btnY += btnHeight + btnGap;

        removeButton_ = CreateWindowExW(
            0,
            L"BUTTON",
            L"\u5220\u9664", // "删除"
            WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            btnX,
            btnY,
            btnWidth,
            btnHeight,
            hwnd,
            reinterpret_cast<HMENU>(static_cast<INT_PTR>(kIdRemoveButton)),
            hInstance_,
            nullptr
        );
        btnY += btnHeight + btnGap;

        moveUpButton_ = CreateWindowExW(
            0,
            L"BUTTON",
            L"\u4e0a\u79fb", // "上移"
            WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            btnX,
            btnY,
            btnWidth,
            btnHeight,
            hwnd,
            reinterpret_cast<HMENU>(static_cast<INT_PTR>(kIdMoveUpButton)),
            hInstance_,
            nullptr
        );
        btnY += btnHeight + btnGap;

        moveDownButton_ = CreateWindowExW(
            0,
            L"BUTTON",
            L"\u4e0b\u79fb", // "下移"
            WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            btnX,
            btnY,
            btnWidth,
            btnHeight,
            hwnd,
            reinterpret_cast<HMENU>(static_cast<INT_PTR>(kIdMoveDownButton)),
            hInstance_,
            nullptr
        );

        // 行为设置页控件：顶部区域下的分组框和复选框
        const int groupX = 20;
        const int groupY = 50;
        const int groupWidth = 500;
        const int groupHeight = 110;

        behaviorGroupBox_ = CreateWindowExW(
            0,
            L"BUTTON",
            L"\u884c\u4e3a\u8bbe\u7f6e", // "行为设置"
            WS_CHILD | WS_VISIBLE | BS_GROUPBOX,
            groupX,
            groupY,
            groupWidth,
            groupHeight,
            hwnd,
            nullptr,
            hInstance_,
            nullptr
        );

        // 复选框：休息结束后自动隐藏遮罩并开始下一番茄
        autoHideCheckbox_ = CreateWindowExW(
            0,
            L"BUTTON",
            L"\u4f11\u606f\u7ed3\u675f\u540e\u81ea\u52a8\u9690\u85cf\u906e\u7f69\u5c42\u5e76\u5f00\u59cb\u4e0b\u4e00\u4e2a\u756a\u8304\u949f", // "休息结束后自动隐藏遮罩层并开始下一个番茄钟"
            WS_CHILD | WS_VISIBLE | BS_AUTOCHECKBOX,
            groupX + 15,
            groupY + 18,
            groupWidth - 30,
            18,
            hwnd,
            reinterpret_cast<HMENU>(static_cast<INT_PTR>(kIdAutoHideCheckbox)),
            hInstance_,
            nullptr
        );

        SendMessageW(
            autoHideCheckbox_,
            BM_SETCHECK,
            settings_.autoHideOverlayAfterRest() ? BST_CHECKED : BST_UNCHECKED,
            0
        );

        // 默认切换到“行为设置”标签页
        switchToTab(0);

        refreshList();
    }

    void SettingsWindowWin32::onDestroy() {
        // 这里暂时不做额外清理，配置持久化交由调用方在适当时机执行
    }

    void SettingsWindowWin32::refreshList() {
        if (!listBox_) return;
        SendMessageW(listBox_, LB_RESETCONTENT, 0, 0);

        for (const auto& file : settings_.files()) {
            std::wstring prefix = (file.type == BackgroundType::Image) ? L"[\u56fe] " : L"[\u89c6] "; // "[图] " / "[视] "
            std::wstring display = prefix + file.name;
            SendMessageW(listBox_, LB_ADDSTRING, 0, reinterpret_cast<LPARAM>(display.c_str()));
        }
    }

    void SettingsWindowWin32::onAddImage() {
        wchar_t fileBuffer[MAX_PATH] = { 0 };

        OPENFILENAMEW ofn{};
        ofn.lStructSize = sizeof(ofn);
        ofn.hwndOwner = hwnd_;
        ofn.lpstrFile = fileBuffer;
        // 使用 sizeof 计算缓冲区长度，避免依赖 std::size 的 C++17 实现差异
        ofn.nMaxFile = static_cast<DWORD>(sizeof(fileBuffer) / sizeof(fileBuffer[0]));
        ofn.lpstrFilter = L"图片文件 (*.jpg;*.jpeg;*.png;*.bmp;*.gif)\0*.jpg;*.jpeg;*.png;*.bmp;*.gif\0所有文件 (*.*)\0*.*\0\0";
        ofn.nFilterIndex = 1;
        ofn.Flags = OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST | OFN_EXPLORER;

        if (GetOpenFileNameW(&ofn)) {
            std::wstring path = fileBuffer;
            BackgroundFileWin32 file;
            file.path = path;
            file.type = BackgroundType::Image;
            file.name = ExtractFileName(path);
            file.playbackRate = 1.0;
            settings_.files().push_back(std::move(file));
            refreshList();
            // 立即持久化到用户配置目录，供遮罩层读取
            settings_.saveToFile(BackgroundSettingsWin32::DefaultConfigPath());
        }
    }

    void SettingsWindowWin32::onAddVideo() {
        wchar_t fileBuffer[MAX_PATH] = { 0 };

        OPENFILENAMEW ofn{};
        ofn.lStructSize = sizeof(ofn);
        ofn.hwndOwner = hwnd_;
        ofn.lpstrFile = fileBuffer;
        ofn.nMaxFile = static_cast<DWORD>(sizeof(fileBuffer) / sizeof(fileBuffer[0]));
        ofn.lpstrFilter = L"视频文件 (*.mp4;*.mov;*.avi;*.mkv)\0*.mp4;*.mov;*.avi;*.mkv\0所有文件 (*.*)\0*.*\0\0";
        ofn.nFilterIndex = 1;
        ofn.Flags = OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST | OFN_EXPLORER;

        if (GetOpenFileNameW(&ofn)) {
            std::wstring path = fileBuffer;
            BackgroundFileWin32 file;
            file.path = path;
            file.type = BackgroundType::Video;
            file.name = ExtractFileName(path);
            file.playbackRate = 1.0; // TODO: 将来可在设置面板中增加播放速率调节
            settings_.files().push_back(std::move(file));
            refreshList();
            settings_.saveToFile(BackgroundSettingsWin32::DefaultConfigPath());
        }
    }

    void SettingsWindowWin32::onRemove() {
        if (!listBox_) return;
        LRESULT sel = SendMessageW(listBox_, LB_GETCURSEL, 0, 0);
        if (sel == LB_ERR) return;

        int index = static_cast<int>(sel);
        auto& files = settings_.files();
        if (index < 0 || index >= static_cast<int>(files.size())) return;

        files.erase(files.begin() + index);
        refreshList();
        settings_.saveToFile(BackgroundSettingsWin32::DefaultConfigPath());
    }

    void SettingsWindowWin32::onAutoHideChanged() {
        if (!autoHideCheckbox_) return;
        LRESULT state = SendMessageW(autoHideCheckbox_, BM_GETCHECK, 0, 0);
        bool enabled = (state == BST_CHECKED);
        settings_.setAutoHideOverlayAfterRest(enabled);
        settings_.saveToFile(BackgroundSettingsWin32::DefaultConfigPath());
    }

    void SettingsWindowWin32::switchToTab(int index) {
        activeTabIndex_ = index;

        // 更新“标签”按钮的可用状态（当前页禁用，看起来类似选中状态）
        if (behaviorTabButton_) {
            EnableWindow(behaviorTabButton_, index != 0);
        }
        if (backgroundTabButton_) {
            EnableWindow(backgroundTabButton_, index != 1);
        }

        const BOOL showBehavior = (index == 0) ? TRUE : FALSE;
        const BOOL showBackground = (index == 1) ? TRUE : FALSE;

        // 行为设置页控件
        if (behaviorGroupBox_) {
            ShowWindow(behaviorGroupBox_, showBehavior ? SW_SHOW : SW_HIDE);
        }
        if (autoHideCheckbox_) {
            ShowWindow(autoHideCheckbox_, showBehavior ? SW_SHOW : SW_HIDE);
        }

        // 背景设置页控件
        if (listBox_) {
            ShowWindow(listBox_, showBackground ? SW_SHOW : SW_HIDE);
        }
        if (addImageButton_) {
            ShowWindow(addImageButton_, showBackground ? SW_SHOW : SW_HIDE);
        }
        if (addVideoButton_) {
            ShowWindow(addVideoButton_, showBackground ? SW_SHOW : SW_HIDE);
        }
        if (removeButton_) {
            ShowWindow(removeButton_, showBackground ? SW_SHOW : SW_HIDE);
        }
        if (moveUpButton_) {
            ShowWindow(moveUpButton_, showBackground ? SW_SHOW : SW_HIDE);
        }
        if (moveDownButton_) {
            ShowWindow(moveDownButton_, showBackground ? SW_SHOW : SW_HIDE);
        }
    }

    void SettingsWindowWin32::onMoveUp() {
        if (!listBox_) return;
        LRESULT sel = SendMessageW(listBox_, LB_GETCURSEL, 0, 0);
        if (sel == LB_ERR) return;

        int index = static_cast<int>(sel);
        auto& files = settings_.files();
        if (index <= 0 || index >= static_cast<int>(files.size())) return;

        std::swap(files[index - 1], files[index]);
        refreshList();
        SendMessageW(listBox_, LB_SETCURSEL, index - 1, 0);
        settings_.saveToFile(BackgroundSettingsWin32::DefaultConfigPath());
    }

    void SettingsWindowWin32::onMoveDown() {
        if (!listBox_) return;
        LRESULT sel = SendMessageW(listBox_, LB_GETCURSEL, 0, 0);
        if (sel == LB_ERR) return;

        int index = static_cast<int>(sel);
        auto& files = settings_.files();
        if (index < 0 || index >= static_cast<int>(files.size()) - 1) return;

        std::swap(files[index], files[index + 1]);
        refreshList();
        SendMessageW(listBox_, LB_SETCURSEL, index + 1, 0);
        settings_.saveToFile(BackgroundSettingsWin32::DefaultConfigPath());
    }

} // namespace pomodoro



