#include "TrayPopupWindowWin32.h"

#include <gdiplus.h>
#include <shellapi.h>
#include <windowsx.h> // for GET_X_LPARAM / GET_Y_LPARAM

namespace {

    const wchar_t* kTrayPopupWindowClassName = L"PomodoroTrayPopupWindowClass";

    // 控件 ID（仅在弹窗内部使用）
    constexpr int kIdStartButton = 3001;   // 作为“启动 / 暂停”切换按钮
    constexpr int kIdResetButton = 3003;
    constexpr int kIdSettingsButton = 3004; // 右上角“设置”图标按钮

    enum class TaskbarEdge {
        Bottom,
        Top,
        Left,
        Right,
        Unknown
    };

    TaskbarEdge GetTaskbarEdge() {
        APPBARDATA abd{};
        abd.cbSize = sizeof(abd);
        if (!SHAppBarMessage(ABM_GETTASKBARPOS, &abd)) {
            return TaskbarEdge::Unknown;
        }

        switch (abd.uEdge) {
        case ABE_BOTTOM: return TaskbarEdge::Bottom;
        case ABE_TOP:    return TaskbarEdge::Top;
        case ABE_LEFT:   return TaskbarEdge::Left;
        case ABE_RIGHT:  return TaskbarEdge::Right;
        default:         return TaskbarEdge::Unknown;
        }
    }

    ATOM RegisterTrayPopupWindowClass(HINSTANCE hInstance) {
        static ATOM s_atom = 0;
        if (s_atom != 0) return s_atom;

        WNDCLASSEXW wc{};
        wc.cbSize = sizeof(WNDCLASSEXW);
        wc.style = CS_HREDRAW | CS_VREDRAW;
        wc.lpfnWndProc = pomodoro::TrayPopupWindowWin32::WndProc;
        wc.cbClsExtra = 0;
        wc.cbWndExtra = sizeof(LONG_PTR);
        wc.hInstance = hInstance;
        wc.hIcon = nullptr;
        wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
        wc.hbrBackground = nullptr; // 自绘
        wc.lpszMenuName = nullptr;
        wc.lpszClassName = kTrayPopupWindowClassName;
        wc.hIconSm = nullptr;

        s_atom = RegisterClassExW(&wc);
        return s_atom;
    }

} // namespace

namespace pomodoro {

    TrayPopupWindowWin32::TrayPopupWindowWin32() {
        statusText_ = L"\u5de5\u4f5c\u4e2d"; // "工作中"
        timeText_ = L"00:00";
    }

    TrayPopupWindowWin32::~TrayPopupWindowWin32() {
        if (hwnd_) {
            DestroyWindow(hwnd_);
            hwnd_ = nullptr;
        }
    }

    bool TrayPopupWindowWin32::create(HINSTANCE hInstance) {
        hInstance_ = hInstance;

        if (!RegisterTrayPopupWindowClass(hInstance_)) {
            return false;
        }

        // 先创建一个隐藏窗口，稍后在 showNearCursor 中定位
        hwnd_ = CreateWindowExW(
            WS_EX_TOOLWINDOW | WS_EX_TOPMOST,
            kTrayPopupWindowClassName,
            L"Pomodoro Popup",
            WS_POPUP,
            CW_USEDEFAULT,
            CW_USEDEFAULT,
            260,
            160, // 为按钮预留高度
            nullptr,
            nullptr,
            hInstance_,
            this
        );

        return hwnd_ != nullptr;
    }

    void TrayPopupWindowWin32::showNearCursor() {
        if (!hwnd_) return;

        POINT pt{};
        GetCursorPos(&pt);

        RECT rc{};
        GetWindowRect(hwnd_, &rc);
        int width = rc.right - rc.left;
        int height = rc.bottom - rc.top;

        // 根据任务栏位置决定弹窗的相对位置
        TaskbarEdge edge = GetTaskbarEdge();

        int x = pt.x - width / 2;
        int y = pt.y - height - 10; // 默认认为任务栏在下方，弹窗在上方

        switch (edge) {
        case TaskbarEdge::Bottom:
            // 任务栏在底部：弹窗显示在鼠标上方
            x = pt.x - width / 2;
            y = pt.y - height - 10;
            break;
        case TaskbarEdge::Top:
            // 任务栏在顶部：弹窗显示在鼠标下方
            x = pt.x - width / 2;
            y = pt.y + 10;
            break;
        case TaskbarEdge::Left:
            // 任务栏在左侧：弹窗显示在鼠标右侧
            x = pt.x + 10;
            y = pt.y - height / 2;
            break;
        case TaskbarEdge::Right:
            // 任务栏在右侧：弹窗显示在鼠标左侧
            x = pt.x - width - 10;
            y = pt.y - height / 2;
            break;
        case TaskbarEdge::Unknown:
        default:
            // 回退到默认行为（假设任务栏在底部）
            x = pt.x - width / 2;
            y = pt.y - height - 10;
            break;
        }

        // 将弹窗限制在当前显示器工作区域内，避免超出屏幕
        HMONITOR monitor = MonitorFromPoint(pt, MONITOR_DEFAULTTONEAREST);
        MONITORINFO mi{};
        mi.cbSize = sizeof(mi);
        if (GetMonitorInfoW(monitor, &mi)) {
            RECT work = mi.rcWork;
            if (x + width > work.right) {
                x = work.right - width - 2;
            }
            if (x < work.left) {
                x = work.left + 2;
            }
            if (y + height > work.bottom) {
                y = work.bottom - height - 2;
            }
            if (y < work.top) {
                y = work.top + 2;
            }
        }

        SetWindowPos(
            hwnd_,
            HWND_TOPMOST,
            x,
            y,
            0,
            0,
            SWP_NOSIZE | SWP_NOACTIVATE
        );

        ShowWindow(hwnd_, SW_SHOWNOACTIVATE);
        UpdateWindow(hwnd_);
    }

    void TrayPopupWindowWin32::hide() {
        if (!hwnd_) return;
        ShowWindow(hwnd_, SW_HIDE);
    }

    void TrayPopupWindowWin32::updateContent(const std::wstring& statusText, const std::wstring& timeText) {
        statusText_ = statusText;
        timeText_ = timeText;
        if (hwnd_ && IsWindowVisible(hwnd_)) {
            InvalidateRect(hwnd_, nullptr, FALSE);
        }
    }

    LRESULT CALLBACK TrayPopupWindowWin32::WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
        TrayPopupWindowWin32* self = nullptr;

        if (msg == WM_NCCREATE) {
            auto* cs = reinterpret_cast<CREATESTRUCTW*>(lParam);
            self = static_cast<TrayPopupWindowWin32*>(cs->lpCreateParams);
            SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
        } else {
            self = reinterpret_cast<TrayPopupWindowWin32*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
        }

        if (self) {
            return self->handleMessage(hwnd, msg, wParam, lParam);
        }

        return DefWindowProcW(hwnd, msg, wParam, lParam);
    }

    LRESULT TrayPopupWindowWin32::handleMessage(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
        switch (msg) {
        case WM_CREATE: {
            // 创建按钮控件：启动/暂停（单个切换按钮）+ 重置 + 设置
            RECT client{};
            GetClientRect(hwnd, &client);

            const int btnWidth = 80;
            const int btnHeight = 24;
            const int btnSpacing = 16;

            int totalWidth = btnWidth * 2 + btnSpacing;
            int startX = (client.right - client.left - totalWidth) / 2;
            int y = (client.bottom - client.top) - btnHeight - 14;

            const wchar_t* startText = isRunning_ ? L"\u6682\u505c" : L"\u542f\u52a8"; // "暂停" / "启动"

            btnStart_ = CreateWindowExW(
                0,
                L"BUTTON",
                startText,
                WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
                startX,
                y,
                btnWidth,
                btnHeight,
                hwnd,
                reinterpret_cast<HMENU>(static_cast<INT_PTR>(kIdStartButton)),
                hInstance_,
                nullptr
            );

            btnReset_ = CreateWindowExW(
                0,
                L"BUTTON",
                L"\u91cd\u7f6e", // "重置"
                WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
                startX + btnWidth + btnSpacing,
                y,
                btnWidth,
                btnHeight,
                hwnd,
                reinterpret_cast<HMENU>(static_cast<INT_PTR>(kIdResetButton)),
                hInstance_,
                nullptr
            );

            // 右上角“设置”按钮
            const int settingsWidth = 60;
            const int settingsHeight = 22;
            btnSettings_ = CreateWindowExW(
                0,
                L"BUTTON",
                L"", // 文本由自绘图标代替
                WS_CHILD | WS_VISIBLE | BS_OWNERDRAW,
                client.right - settingsWidth - 10,
                8,
                settingsWidth,
                settingsHeight,
                hwnd,
                reinterpret_cast<HMENU>(static_cast<INT_PTR>(kIdSettingsButton)),
                hInstance_,
                nullptr
            );

            return 0;
        }

        case WM_LBUTTONDOWN:
        case WM_RBUTTONDOWN: {
            // 仅在点击空白区域时关闭弹窗；点击按钮时让按钮接收消息
            POINT pt{ GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam) };
            HWND child = ChildWindowFromPoint(hwnd, pt);
            if (child == hwnd) {
                hide();
                return 0;
            }
            break;
        }

        case WM_COMMAND: {
            const int id = LOWORD(wParam);
            const int code = HIWORD(wParam);
            if (code == BN_CLICKED) {
                switch (id) {
                case kIdStartButton:
                    // 根据当前运行状态分派到启动/暂停逻辑
                    if (isRunning_) {
                        if (onPauseClicked_) onPauseClicked_();
                    } else {
                        if (onStartClicked_) onStartClicked_();
                    }
                    break;
                case kIdResetButton:
                    if (onResetClicked_) onResetClicked_();
                    break;
                case kIdSettingsButton:
                    if (onSettingsClicked_) onSettingsClicked_();
                    break;
                default:
                    break;
                }
            }
            return 0;
        }

        case WM_PAINT:
            paint();
            return 0;

        case WM_DRAWITEM: {
            auto* dis = reinterpret_cast<LPDRAWITEMSTRUCT>(lParam);
            if (!dis) break;

            if (dis->CtlID == kIdSettingsButton) {
                HDC hdc = dis->hDC;
                RECT rc = dis->rcItem;

                const bool isPressed = (dis->itemState & ODS_SELECTED) != 0;

                // 背景与弹窗一致（无额外边框，仅深色背景上绘制齿轮）
                HBRUSH bgBrush = CreateSolidBrush(RGB(32, 32, 40));
                FillRect(hdc, &rc, bgBrush);
                DeleteObject(bgBrush);

                // 绘制“齿轮”图标（使用 Segoe UI Symbol 字体的 U+2699）
                SetBkMode(hdc, TRANSPARENT);
                SetTextColor(hdc, isPressed ? RGB(230, 230, 240) : RGB(200, 200, 216));

                LOGFONTW lf{};
                lf.lfHeight = -14;
                lf.lfWeight = FW_NORMAL;
                wcscpy_s(lf.lfFaceName, L"Segoe UI Symbol");
                HFONT font = CreateFontIndirectW(&lf);
                HFONT oldFont = static_cast<HFONT>(SelectObject(hdc, font));

                RECT textRc = rc;
                const wchar_t* gear = L"\u2699"; // ⚙
                DrawTextW(hdc, gear, -1, &textRc, DT_CENTER | DT_VCENTER | DT_SINGLELINE);

                SelectObject(hdc, oldFont);
                DeleteObject(font);

                return TRUE;
            }
            break;
        }

        case WM_ERASEBKGND:
            // 由 WM_PAINT 完成绘制
            return 1;

        default:
            break;
        }

        return DefWindowProcW(hwnd, msg, wParam, lParam);
    }

    void TrayPopupWindowWin32::paint() {
        if (!hwnd_) return;

        PAINTSTRUCT ps;
        HDC hdc = BeginPaint(hwnd_, &ps);
        if (!hdc) return;

        RECT client{};
        GetClientRect(hwnd_, &client);

        // 背景：深灰色矩形，圆角感由内容决定（简单实现为矩形）
        HBRUSH bgBrush = CreateSolidBrush(RGB(32, 32, 40));
        FillRect(hdc, &client, bgBrush);
        DeleteObject(bgBrush);

        // 边框
        HPEN borderPen = CreatePen(PS_SOLID, 1, RGB(80, 80, 96));
        HGDIOBJ oldPen = SelectObject(hdc, borderPen);
        HGDIOBJ oldBrush = SelectObject(hdc, GetStockObject(HOLLOW_BRUSH));
        Rectangle(hdc, client.left, client.top, client.right - 1, client.bottom - 1);
        SelectObject(hdc, oldPen);
        SelectObject(hdc, oldBrush);
        DeleteObject(borderPen);

        // 标题：状态文本
        SetBkMode(hdc, TRANSPARENT);
        SetTextColor(hdc, RGB(255, 255, 255));

        RECT statusRect = client;
        statusRect.left += 16;
        statusRect.top += 12;
        statusRect.bottom = statusRect.top + 24;

        DrawTextW(hdc, statusText_.c_str(), -1, &statusRect, DT_LEFT | DT_VCENTER | DT_SINGLELINE);

        // 倒计时：大号字体，居中显示，预留底部按钮区域
        LOGFONTW lf{};
        lf.lfHeight = -28;
        lf.lfWeight = FW_SEMIBOLD;
        wcscpy_s(lf.lfFaceName, L"Segoe UI");
        HFONT font = CreateFontIndirectW(&lf);
        HFONT oldFont = static_cast<HFONT>(SelectObject(hdc, font));

        RECT timeRect = client;
        timeRect.top = statusRect.bottom + 8;
        timeRect.bottom = timeRect.bottom - 56; // 预留按钮区域高度
        DrawTextW(hdc, timeText_.c_str(), -1, &timeRect, DT_CENTER | DT_VCENTER | DT_SINGLELINE);

        SelectObject(hdc, oldFont);
        DeleteObject(font);

        EndPaint(hwnd_, &ps);
    }

    void TrayPopupWindowWin32::setRunningState(bool running) {
        isRunning_ = running;
        if (btnStart_) {
            const wchar_t* text = isRunning_ ? L"\u6682\u505c" : L"\u542f\u52a8"; // "暂停" / "启动"
            SetWindowTextW(btnStart_, text);
        }
    }

} // namespace pomodoro



