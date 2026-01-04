#include "SettingsWindowWin32.h"
#include "DpiUtilsWin32.h"

#include <commctrl.h>
#include <commdlg.h>
#include <vector>
#include <algorithm>

#pragma comment(lib, "Comctl32.lib")

namespace {

    const wchar_t* kSettingsWindowClassName = L"PomodoroSettingsWindowClass";

    // 控件 ID
    constexpr int kIdListBox = 1001;
    constexpr int kIdAddImageButton = 1002;
    constexpr int kIdAddVideoButton = 1003;
    constexpr int kIdRemoveButton = 1004;
    constexpr int kIdMoveUpButton = 1005;
    constexpr int kIdMoveDownButton = 1006;
    constexpr int kIdAutoStartNextPomodoroAfterRestCheckbox = 1007;
    constexpr int kIdPomodoroSlider = 1008;
    constexpr int kIdTabBehavior = 1101;
    constexpr int kIdTabBackground = 1102;
    constexpr int kIdOverlayMessageEdit = 1201;

    std::vector<int> BuildPomodoroMinuteOptions() {
        std::vector<int> out;
        out.reserve(64);

        for (int m = 5; m <= 30; ++m) {
            out.push_back(m);
        }
        for (int m = 35; m <= 120; m += 5) {
            out.push_back(m);
        }
        return out;
    }

    int FindNearestOptionIndex(const std::vector<int>& options, int minutes) {
        if (options.empty()) return 0;

        // 选择“最接近”的值；同距时取更小的（更保守）
        int bestIdx = 0;
        int bestDist = abs(options[0] - minutes);
        for (int i = 1; i < static_cast<int>(options.size()); ++i) {
            const int dist = abs(options[i] - minutes);
            if (dist < bestDist || (dist == bestDist && options[i] < options[bestIdx])) {
                bestIdx = i;
                bestDist = dist;
            }
        }
        return bestIdx;
    }

    std::wstring PomodoroMinutesLabelText(int minutes) {
        // "番茄时长：XX 分钟"
        return L"\u756a\u8304\u65f6\u957f\uff1a" + std::to_wstring(minutes) + L" \u5206\u949f";
    }

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

            // 保险：窗口创建完成后再强制应用一次 DPI 布局（包含窗口尺寸与控件缩放）。
            // 这样即使 WM_CREATE 路径中尺寸未生效，也能在显示前纠正。
            if (hwnd_) {
                applyDpiLayout(pomodoro::win32::GetDpiForHwnd(hwnd_), nullptr);
            }
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
        case WM_DPICHANGED: {
            const UINT newDpi = HIWORD(wParam);
            auto* suggested = reinterpret_cast<RECT*>(lParam);
            applyDpiLayout(newDpi, suggested);
            return 0;
        }
        case WM_HSCROLL: {
            if (reinterpret_cast<HWND>(lParam) == pomodoroSlider_) {
                // 拖动时实时刷新文字；松开时 commit
                const int code = LOWORD(wParam);
                const bool commit = (code == TB_ENDTRACK) || (code == TB_THUMBPOSITION);
                onPomodoroSliderChanged(commit);
                return 0;
            }
            break;
        }
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
                case kIdAutoStartNextPomodoroAfterRestCheckbox:
                    onAutoStartNextPomodoroAfterRestChanged();
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
            if (id == kIdOverlayMessageEdit && code == EN_KILLFOCUS) {
                // Save overlay message when the textbox loses focus.
                if (overlayMessageEdit_) {
                    const int len = GetWindowTextLengthW(overlayMessageEdit_);
                    std::wstring text;
                    if (len > 0) {
                        text.resize(static_cast<std::size_t>(len));
                        GetWindowTextW(overlayMessageEdit_, text.data(), len + 1);
                    }
                    if (text != settings_.overlayMessage()) {
                        settings_.setOverlayMessage(std::move(text));
                        settings_.saveToFile(BackgroundSettingsWin32::DefaultConfigPath());
                    }
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
        dpi_ = pomodoro::win32::GetDpiForHwnd(hwnd);
        if (uiFont_) {
            DeleteObject(uiFont_);
            uiFont_ = nullptr;
        }
        if (bigFont_) {
            DeleteObject(bigFont_);
            bigFont_ = nullptr;
        }
        uiFont_ = pomodoro::win32::CreateUiFontPx(14, FW_NORMAL, L"Segoe UI", dpi_);
        bigFont_ = pomodoro::win32::CreateUiFontPx(16, FW_SEMIBOLD, L"Segoe UI", dpi_);

        // Trackbar 等通用控件初始化（多次调用安全）
        INITCOMMONCONTROLSEX icc{};
        icc.dwSize = sizeof(icc);
        icc.dwICC = ICC_BAR_CLASSES;
        InitCommonControlsEx(&icc);

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

        // 背景设置页控件：自定义遮罩提示文案（失焦保存到 JSON）
        overlayMessageLabel_ = CreateWindowExW(
            0,
            L"STATIC",
            L"\u906e\u7f69\u63d0\u793a\u6587\u6848\uff1a", // "遮罩提示文案："
            WS_CHILD | WS_VISIBLE,
            20,
            50,
            320,
            18,
            hwnd,
            nullptr,
            hInstance_,
            nullptr
        );
        overlayMessageEdit_ = CreateWindowExW(
            WS_EX_CLIENTEDGE,
            L"EDIT",
            settings_.overlayMessage().c_str(),
            WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL,
            20,
            70,
            320,
            24,
            hwnd,
            reinterpret_cast<HMENU>(static_cast<INT_PTR>(kIdOverlayMessageEdit)),
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
        const int groupHeight = 160;

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
            reinterpret_cast<HMENU>(static_cast<INT_PTR>(kIdAutoStartNextPomodoroAfterRestCheckbox)),
            hInstance_,
            nullptr
        );

        SendMessageW(
            autoHideCheckbox_,
            BM_SETCHECK,
            settings_.autoStartNextPomodoroAfterRest() ? BST_CHECKED : BST_UNCHECKED,
            0
        );

        // 番茄钟时长：拖动条 + 文本
        const int sliderX = groupX + 15;
        const int sliderY = groupY + 48;
        const int sliderWidth = groupWidth - 30;

        pomodoroMinutesLabel_ = CreateWindowExW(
            0,
            L"STATIC",
            PomodoroMinutesLabelText(settings_.pomodoroMinutes()).c_str(),
            WS_CHILD | WS_VISIBLE,
            sliderX,
            sliderY,
            sliderWidth,
            18,
            hwnd,
            nullptr,
            hInstance_,
            nullptr
        );

        pomodoroSlider_ = CreateWindowExW(
            0,
            TRACKBAR_CLASSW,
            L"",
            WS_CHILD | WS_VISIBLE | TBS_HORZ,
            sliderX,
            sliderY + 22,
            sliderWidth,
            32,
            hwnd,
            reinterpret_cast<HMENU>(static_cast<INT_PTR>(kIdPomodoroSlider)),
            hInstance_,
            nullptr
        );

        const auto options = BuildPomodoroMinuteOptions();
        const int maxPos = static_cast<int>(options.size()) - 1;
        SendMessageW(pomodoroSlider_, TBM_SETRANGE, TRUE, MAKELONG(0, maxPos));
        SendMessageW(pomodoroSlider_, TBM_SETPAGESIZE, 0, 1);
        SendMessageW(pomodoroSlider_, TBM_SETTICFREQ, 4, 0);

        const int initialIndex = FindNearestOptionIndex(options, settings_.pomodoroMinutes());
        SendMessageW(pomodoroSlider_, TBM_SETPOS, TRUE, initialIndex);
        onPomodoroSliderChanged(false);

        // Apply DPI-based layout + fonts
        applyDpiLayout(dpi_, nullptr);

        // 默认切换到“行为设置”标签页
        switchToTab(0);

        refreshList();
    }

    void SettingsWindowWin32::onDestroy() {
        // 这里暂时不做额外清理，配置持久化交由调用方在适当时机执行
        if (uiFont_) {
            DeleteObject(uiFont_);
            uiFont_ = nullptr;
        }
        if (bigFont_) {
            DeleteObject(bigFont_);
            bigFont_ = nullptr;
        }
    }

    void SettingsWindowWin32::applyDpiLayout(UINT dpi, const RECT* suggestedWindowRect) {
        dpi_ = dpi ? dpi : 96;

        // Update window size if Windows suggests a rect (Per-Monitor DPI change)
        if (suggestedWindowRect && hwnd_) {
            SetWindowPos(
                hwnd_,
                nullptr,
                suggestedWindowRect->left,
                suggestedWindowRect->top,
                suggestedWindowRect->right - suggestedWindowRect->left,
                suggestedWindowRect->bottom - suggestedWindowRect->top,
                SWP_NOZORDER | SWP_NOACTIVATE
            );
        }

        // Refresh fonts at new DPI
        if (uiFont_) {
            DeleteObject(uiFont_);
            uiFont_ = nullptr;
        }
        if (bigFont_) {
            DeleteObject(bigFont_);
            bigFont_ = nullptr;
        }
        uiFont_ = pomodoro::win32::CreateUiFontPx(14, FW_NORMAL, L"Segoe UI", dpi_);
        bigFont_ = pomodoro::win32::CreateUiFontPx(16, FW_SEMIBOLD, L"Segoe UI", dpi_);

        auto S = [&](int v) { return pomodoro::win32::Scale(v, dpi_); };

        // Layout constants (96 DPI baseline)
        // DPI 感知生效后，原 540x420 在高分屏上会显得“偏小”，这里同步放大基础窗口尺寸。
        // 这里的 winW / winH 作为“目标 client 区域尺寸”（用于下面布局计算）。
        // 但真正设置窗口大小时，需要考虑标题栏/边框（non-client），否则 client 会变小导致内容显示不全。
        const int winW = S(680);
        const int winH = S(520);
        if (!suggestedWindowRect && hwnd_) {
            RECT wr{ 0, 0, winW, winH };
            const DWORD style = static_cast<DWORD>(GetWindowLongPtrW(hwnd_, GWL_STYLE));
            const DWORD exStyle = static_cast<DWORD>(GetWindowLongPtrW(hwnd_, GWL_EXSTYLE));
            AdjustWindowRectEx(&wr, style, FALSE, exStyle);
            const int actualW = wr.right - wr.left;
            const int actualH = wr.bottom - wr.top;
            SetWindowPos(
                hwnd_,
                nullptr,
                0,
                0,
                actualW,
                actualH,
                SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED
            );
        }

        // Compute a synthetic client size from our target window size (good enough for layout;
        // we are not doing pixel-perfect non-client calculations in this lightweight UI).
        const int clientW = winW;
        const int clientH = winH;

        const int margin = S(20);
        const int topTabsY = S(10);
        const int tabsH = S(28);
        const int contentTop = S(50);
        const int bottomMargin = S(30);
        const int gap = S(20);

        // Tabs
        if (behaviorTabButton_) {
            SetWindowPos(behaviorTabButton_, nullptr, margin, topTabsY, S(140), tabsH, SWP_NOZORDER | SWP_NOACTIVATE);
            pomodoro::win32::SetControlFont(behaviorTabButton_, uiFont_);
        }
        if (backgroundTabButton_) {
            SetWindowPos(backgroundTabButton_, nullptr, margin + S(150), topTabsY, S(140), tabsH, SWP_NOZORDER | SWP_NOACTIVATE);
            pomodoro::win32::SetControlFont(backgroundTabButton_, uiFont_);
        }

        // Background tab
        const int rightPanelW = S(140);
        const int rightPanelX = clientW - margin - rightPanelW;
        const int listX = margin;
        const int msgLabelH = S(18);
        const int msgEditH = S(30);
        const int msgGap = S(6);
        const int msgToListGap = S(12);
        const int msgY = contentTop;
        const int listY = msgY + msgLabelH + msgGap + msgEditH + msgToListGap;
        const int listW = max(S(260), rightPanelX - gap - listX);
        const int listH = max(S(220), clientH - listY - bottomMargin);

        if (overlayMessageLabel_) {
            SetWindowPos(overlayMessageLabel_, nullptr, listX, msgY, listW, msgLabelH, SWP_NOZORDER | SWP_NOACTIVATE);
            pomodoro::win32::SetControlFont(overlayMessageLabel_, uiFont_);
        }
        if (overlayMessageEdit_) {
            SetWindowPos(overlayMessageEdit_, nullptr, listX, msgY + msgLabelH + msgGap, listW, msgEditH, SWP_NOZORDER | SWP_NOACTIVATE);
            pomodoro::win32::SetControlFont(overlayMessageEdit_, uiFont_);
        }

        if (listBox_) {
            SetWindowPos(listBox_, nullptr, listX, listY, listW, listH, SWP_NOZORDER | SWP_NOACTIVATE);
            pomodoro::win32::SetControlFont(listBox_, uiFont_);
        }

        const int btnX = rightPanelX;
        int btnY = listY + S(20);
        const int btnW = rightPanelW;
        const int btnH = S(32);
        const int btnGap = S(12);

        auto placeBtn = [&](HWND h) {
            if (!h) return;
            SetWindowPos(h, nullptr, btnX, btnY, btnW, btnH, SWP_NOZORDER | SWP_NOACTIVATE);
            pomodoro::win32::SetControlFont(h, uiFont_);
            btnY += btnH + btnGap;
        };

        placeBtn(addImageButton_);
        placeBtn(addVideoButton_);
        placeBtn(removeButton_);
        placeBtn(moveUpButton_);
        placeBtn(moveDownButton_);

        // Behavior tab
        const int groupX = margin;
        const int groupY = contentTop;
        const int groupW = clientW - margin * 2;
        const int groupH = S(240);

        if (behaviorGroupBox_) {
            SetWindowPos(behaviorGroupBox_, nullptr, groupX, groupY, groupW, groupH, SWP_NOZORDER | SWP_NOACTIVATE);
            pomodoro::win32::SetControlFont(behaviorGroupBox_, uiFont_);
        }
        if (autoHideCheckbox_) {
            SetWindowPos(autoHideCheckbox_, nullptr, groupX + S(15), groupY + S(18), groupW - S(30), S(22), SWP_NOZORDER | SWP_NOACTIVATE);
            pomodoro::win32::SetControlFont(autoHideCheckbox_, uiFont_);
        }
        if (pomodoroMinutesLabel_) {
            SetWindowPos(pomodoroMinutesLabel_, nullptr, groupX + S(15), groupY + S(52), groupW - S(30), S(20), SWP_NOZORDER | SWP_NOACTIVATE);
            pomodoro::win32::SetControlFont(pomodoroMinutesLabel_, uiFont_);
        }
        if (pomodoroSlider_) {
            SetWindowPos(pomodoroSlider_, nullptr, groupX + S(15), groupY + S(78), groupW - S(30), S(36), SWP_NOZORDER | SWP_NOACTIVATE);
            pomodoro::win32::SetControlFont(pomodoroSlider_, uiFont_);
        }

        InvalidateRect(hwnd_, nullptr, TRUE);
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

    void SettingsWindowWin32::onAutoStartNextPomodoroAfterRestChanged() {
        if (!autoHideCheckbox_) return;
        LRESULT state = SendMessageW(autoHideCheckbox_, BM_GETCHECK, 0, 0);
        bool enabled = (state == BST_CHECKED);
        settings_.setAutoStartNextPomodoroAfterRest(enabled);
        settings_.saveToFile(BackgroundSettingsWin32::DefaultConfigPath());
        if (onAutoStartNextPomodoroAfterRestChanged_) {
            onAutoStartNextPomodoroAfterRestChanged_(enabled);
        }
    }

    void SettingsWindowWin32::onPomodoroSliderChanged(bool commit) {
        if (!pomodoroSlider_) return;

        const auto options = BuildPomodoroMinuteOptions();
        if (options.empty()) return;

        const LRESULT pos = SendMessageW(pomodoroSlider_, TBM_GETPOS, 0, 0);
        int index = static_cast<int>(pos);
        if (index < 0) index = 0;
        if (index >= static_cast<int>(options.size())) index = static_cast<int>(options.size()) - 1;

        const int minutes = options[index];

        if (pomodoroMinutesLabel_) {
            const std::wstring text = PomodoroMinutesLabelText(minutes);
            SetWindowTextW(pomodoroMinutesLabel_, text.c_str());
        }

        // 仅当值变化时写入配置；commit 时也会触发回调（供主程序更新计时器设置）
        if (settings_.pomodoroMinutes() != minutes) {
            settings_.setPomodoroMinutes(minutes);
            settings_.saveToFile(BackgroundSettingsWin32::DefaultConfigPath());
        }

        if (commit && onPomodoroMinutesChanged_) {
            onPomodoroMinutesChanged_(minutes);
        }
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
        if (pomodoroMinutesLabel_) {
            ShowWindow(pomodoroMinutesLabel_, showBehavior ? SW_SHOW : SW_HIDE);
        }
        if (pomodoroSlider_) {
            ShowWindow(pomodoroSlider_, showBehavior ? SW_SHOW : SW_HIDE);
        }

        // 背景设置页控件
        if (overlayMessageLabel_) {
            ShowWindow(overlayMessageLabel_, showBackground ? SW_SHOW : SW_HIDE);
        }
        if (overlayMessageEdit_) {
            ShowWindow(overlayMessageEdit_, showBackground ? SW_SHOW : SW_HIDE);
        }
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



