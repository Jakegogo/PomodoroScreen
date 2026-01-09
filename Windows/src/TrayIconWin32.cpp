#include "TrayIconWin32.h"

#include <shellapi.h>

namespace {

    // 与 main.cpp 中的 WM_APP+1 保持一致
    constexpr UINT WM_TRAYICON = WM_APP + 1;
    constexpr UINT WM_OPEN_SETTINGS = WM_APP + 2;

    constexpr UINT kMenuIdCompleteNow = 41001;
    constexpr UINT kMenuIdSettings = 41002;
    constexpr UINT kMenuIdExit = 41003;

    // 统一的 'P' 字母图标，右下角用小圆点表示不同状态
    HICON CreateStateIcon(pomodoro::TrayIconState state) {
        // Do not hardcode 16x16: on high-DPI systems the tray icon is larger and Windows will scale,
        // causing blur. Use the system small-icon metrics so the icon is rendered at native size.
        const int sizeX = GetSystemMetrics(SM_CXSMICON);
        const int sizeY = GetSystemMetrics(SM_CYSMICON);
        const int size = (sizeX > 0 && sizeY > 0) ? min(sizeX, sizeY) : 16;

        HDC hdc = GetDC(nullptr);
        HDC memDC = CreateCompatibleDC(hdc);

        HBITMAP colorBmp = CreateCompatibleBitmap(hdc, size, size);
        HBITMAP maskBmp = CreateBitmap(size, size, 1, 1, nullptr);

        HGDIOBJ oldBmp = SelectObject(memDC, colorBmp);

        // 统一背景（深灰色），保证在浅/深主题下都清晰
        HBRUSH bgBrush = CreateSolidBrush(RGB(32, 32, 40));
        RECT rc = { 0, 0, size, size };
        FillRect(memDC, &rc, bgBrush);
        DeleteObject(bgBrush);

        // 绘制大写 'P' 作为主标识
        SetBkMode(memDC, TRANSPARENT);
        SetTextColor(memDC, RGB(255, 255, 255));

        LOGFONTW lf = {};
        lf.lfHeight = -MulDiv(13, size, 16);
        lf.lfWeight = FW_BOLD;
        wcscpy_s(lf.lfFaceName, L"Segoe UI");
        HFONT font = CreateFontIndirectW(&lf);
        HFONT oldFont = static_cast<HFONT>(SelectObject(memDC, font));

        DrawTextW(memDC, L"P", -1, &rc, DT_CENTER | DT_VCENTER | DT_SINGLELINE);

        SelectObject(memDC, oldFont);
        DeleteObject(font);

        // 在右下角绘制状态小圆点（下标）
        COLORREF dotColor = RGB(0, 200, 0); // 默认工作（绿色）
        switch (state) {
        case pomodoro::TrayIconState::Work:
            dotColor = RGB(0, 200, 0); // 绿色
            break;
        case pomodoro::TrayIconState::Rest:
            dotColor = RGB(0, 160, 255); // 蓝色
            break;
        case pomodoro::TrayIconState::ForcedSleep:
            dotColor = RGB(180, 0, 200); // 紫色
            break;
        }

        HBRUSH dotBrush = CreateSolidBrush(dotColor);
        HGDIOBJ oldBrush = SelectObject(memDC, dotBrush);

        const int dotSize = max(4, MulDiv(5, size, 16));
        RECT dotRc = {
            size - dotSize - 1,
            size - dotSize - 1,
            size - 1,
            size - 1
        };
        Ellipse(memDC, dotRc.left, dotRc.top, dotRc.right, dotRc.bottom);

        SelectObject(memDC, oldBrush);
        DeleteObject(dotBrush);

        SelectObject(memDC, oldBmp);

        ICONINFO ii = {};
        ii.fIcon = TRUE;
        ii.hbmColor = colorBmp;
        ii.hbmMask = maskBmp;

        HICON hIcon = CreateIconIndirect(&ii);

        DeleteObject(colorBmp);
        DeleteObject(maskBmp);
        DeleteDC(memDC);
        ReleaseDC(nullptr, hdc);

        return hIcon;
    }

} // namespace

namespace pomodoro {

    namespace {
        bool PointInRect(const RECT& rc, POINT pt) {
            return pt.x >= rc.left && pt.x < rc.right && pt.y >= rc.top && pt.y < rc.bottom;
        }

        bool IsPointNear(POINT a, POINT b, int thresholdPx) {
            const int dx = a.x - b.x;
            const int dy = a.y - b.y;
            return (dx >= -thresholdPx && dx <= thresholdPx) && (dy >= -thresholdPx && dy <= thresholdPx);
        }
    } // namespace

    TrayIconWin32::TrayIconWin32(HINSTANCE hInstance, HWND messageHwnd, PomodoroTimer& timer)
        : hInstance_(hInstance)
        , messageHwnd_(messageHwnd)
        , timer_(timer) {
        workIcon_ = CreateStateIcon(TrayIconState::Work);
        restIcon_ = CreateStateIcon(TrayIconState::Rest);
        forcedIcon_ = CreateStateIcon(TrayIconState::ForcedSleep);

        popup_.create(hInstance_);

        // 绑定弹窗中的按钮行为到核心计时逻辑（与控制台 s/p/r 命令保持一致）
        popup_.setStartHandler([this]() {
            // Swift 版本中，“启动”既用于首次启动，也用于从暂停恢复
            if (timer_.isPausedState() || timer_.canResume()) {
                timer_.resume();
            } else {
                timer_.start();
            }
        });

        popup_.setPauseHandler([this]() {
            timer_.pause();
        });

        popup_.setResetHandler([this]() {
            // 简单重置：停止当前计时并重新开始一个新的番茄
            timer_.stop();
            timer_.start();
        });

        // 设置按钮：通过隐藏主窗口发送消息，请求打开设置面板
        popup_.setSettingsHandler([this]() {
            if (messageHwnd_) {
                PostMessageW(messageHwnd_, WM_APP + 2, 0, 0);
            }
        });

        initNotifyIcon();

        lastTimeText_ = L"00:00";
    }

    TrayIconWin32::~TrayIconWin32() {
        nid_.uFlags = NIF_GUID;
        Shell_NotifyIconW(NIM_DELETE, &nid_);

        if (workIcon_) DestroyIcon(workIcon_);
        if (restIcon_) DestroyIcon(restIcon_);
        if (forcedIcon_) DestroyIcon(forcedIcon_);
    }

    void TrayIconWin32::initNotifyIcon() {
        ZeroMemory(&nid_, sizeof(nid_));
        nid_.cbSize = sizeof(nid_);
        nid_.hWnd = messageHwnd_;
        nid_.uID = 1;
        // Tooltip is intentionally disabled; popup UI is the primary surface.
        nid_.uFlags = NIF_MESSAGE | NIF_ICON;
        nid_.uCallbackMessage = WM_TRAYICON;
        nid_.hIcon = workIcon_ ? workIcon_ : LoadIcon(nullptr, IDI_APPLICATION);

        Shell_NotifyIconW(NIM_ADD, &nid_);
    }

    void TrayIconWin32::updateTime(const std::string& timeText, bool isRest, bool isForcedSleep, bool isRunning) {
        // 记录时间字符串（转换为 UTF-16）
        int len = static_cast<int>(timeText.size());
        std::wstring wtime(len, L' ');
        MultiByteToWideChar(CP_UTF8, 0, timeText.c_str(), len, &wtime[0], len);
        lastTimeText_ = wtime;

        // 选择状态
        TrayIconState state = TrayIconState::Work;
        if (isForcedSleep) {
            state = TrayIconState::ForcedSleep;
        } else if (isRest) {
            state = TrayIconState::Rest;
        }

        lastState_ = state;
        lastRunning_ = isRunning;

        updateIcon(state, isRunning);

        // 同步弹窗内容（如果当前可见）
        std::wstring status;
        switch (state) {
        case TrayIconState::Work:
            status = isRunning ? L"\u4e13\u6ce8\u4e2d" : L"\u5df2\u6682\u505c"; // "专注中" / "已暂停"
            break;
        case TrayIconState::Rest:
            status = L"\u4f11\u606f\u65f6\u95f4"; // "休息时间"
            break;
        case TrayIconState::ForcedSleep:
            status = L"\u5f3a\u5236\u4f11\u606f"; // "强制休息"
            break;
        }
        popup_.updateContent(status, lastTimeText_);
        popup_.setRunningState(isRunning);
    }

    void TrayIconWin32::updateIcon(TrayIconState state, bool /*isRunning*/) {
        HICON icon = workIcon_;
        switch (state) {
        case TrayIconState::Work:
            icon = workIcon_;
            break;
        case TrayIconState::Rest:
            icon = restIcon_;
            break;
        case TrayIconState::ForcedSleep:
            icon = forcedIcon_;
            break;
        }

        nid_.hIcon = icon;
        nid_.uFlags = NIF_ICON;
        Shell_NotifyIconW(NIM_MODIFY, &nid_);
    }

    void TrayIconWin32::togglePopup() {
        if (popup_.isVisible()) {
            popup_.hide();
        } else {
            popup_.updateContent(L"", lastTimeText_);
            popup_.showNearCursor();
        }
    }

    void TrayIconWin32::showPopupIfNeeded() {
        if (popup_.isVisible()) return;

        // 悬停弹出时也先刷新内容，确保状态与倒计时是最新的
        std::wstring status;
        switch (lastState_) {
        case TrayIconState::Work:
            status = lastRunning_ ? L"\u4e13\u6ce8\u4e2d" : L"\u5df2\u6682\u505c"; // "专注中" / "已暂停"
            break;
        case TrayIconState::Rest:
            status = L"\u4f11\u606f\u65f6\u95f4"; // "休息时间"
            break;
        case TrayIconState::ForcedSleep:
            status = L"\u5f3a\u5236\u4f11\u606f"; // "强制休息"
            break;
        }
        popup_.updateContent(status, lastTimeText_);
        popup_.setRunningState(lastRunning_);
        popup_.showNearCursor();
    }

    void TrayIconWin32::hidePopupIfNeeded() {
        if (!popup_.isVisible()) return;
        popup_.hide();
    }

    void TrayIconWin32::handleTrayMessage(WPARAM wParam, LPARAM lParam) {
        if (LOWORD(wParam) != nid_.uID) return;

        switch (LOWORD(lParam)) {
        case WM_MOUSEMOVE: {
            // 悬停显示弹窗：收到鼠标移动后启动一个轻量定时器，避免瞬间弹出造成抖动
            const DWORD now = GetTickCount();
            POINT pt{};
            GetCursorPos(&pt);
            lastTrayCursorPos_ = pt;
            hasLastTrayCursorPos_ = true;

            // 如果之前不处于 hover，或已经很久没收到鼠标移动（说明离开后又回来），则重置 hover 起点
            if (!hoveringIcon_ || (now - lastMouseMoveTick_) > 200) {
                hoverStartTick_ = now;
            }
            hoveringIcon_ = true;
            lastMouseMoveTick_ = now;
            if (!pinnedByClick_ && messageHwnd_) {
                SetTimer(messageHwnd_, kHoverTimerId, 50, nullptr);
            }
            break;
        }
        case WM_LBUTTONUP:
            // 点击逻辑：
            // - 如果弹窗是“悬停弹出”的（未 pinned），点击应当“固定”它，而不是 toggle 关闭（避免闪现一次又隐藏）
            // - 如果弹窗已 pinned，则点击关闭
            if (popup_.isVisible()) {
                if (!pinnedByClick_) {
                    pinnedByClick_ = true;
                    hoveringIcon_ = false;
                    KillTimer(messageHwnd_, kHoverTimerId);
                } else {
                    popup_.hide();
                    pinnedByClick_ = false;
                }
            } else {
                popup_.updateContent(L"", lastTimeText_);
                popup_.showNearCursor();
                pinnedByClick_ = true;
                hoveringIcon_ = false;
                KillTimer(messageHwnd_, kHoverTimerId);
            }
            break;
        case WM_RBUTTONUP: {
            // 右键：显示菜单（立即完成 / 设置）
            hoveringIcon_ = false;
            pinnedByClick_ = false;
            KillTimer(messageHwnd_, kHoverTimerId);

            if (popup_.isVisible()) {
                popup_.hide();
            }

            if (messageHwnd_) {
                SetForegroundWindow(messageHwnd_);
            }

            HMENU menu = CreatePopupMenu();
            if (menu) {
                AppendMenuW(menu, MF_STRING, kMenuIdCompleteNow, L"\u7acb\u5373\u5b8c\u6210"); // "立即完成"
                AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
                AppendMenuW(menu, MF_STRING, kMenuIdSettings, L"\u8bbe\u7f6e"); // "设置"
                AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
                AppendMenuW(menu, MF_STRING, kMenuIdExit, L"\u9000\u51fa"); // "退出"

                POINT pt{};
                GetCursorPos(&pt);

                const UINT cmd = TrackPopupMenuEx(
                    menu,
                    TPM_RIGHTBUTTON | TPM_RETURNCMD,
                    pt.x,
                    pt.y,
                    messageHwnd_ ? messageHwnd_ : nullptr,
                    nullptr
                );

                DestroyMenu(menu);

                // Ensure menu closes properly
                if (messageHwnd_) {
                    PostMessageW(messageHwnd_, WM_NULL, 0, 0);
                }

                if (cmd == kMenuIdCompleteNow) {
                    // End current pomodoro immediately -> triggers existing overlay flow via onTimerFinished callback.
                    timer_.finishNow();
                } else if (cmd == kMenuIdSettings) {
                    if (messageHwnd_) {
                        PostMessageW(messageHwnd_, WM_OPEN_SETTINGS, 0, 0);
                    }
                } else if (cmd == kMenuIdExit) {
                    // Close the hidden main window -> WM_DESTROY posts WM_QUIT -> exits main loop.
                    if (messageHwnd_) {
                        PostMessageW(messageHwnd_, WM_CLOSE, 0, 0);
                    }
                }
            }
            break;
        }
        default:
            break;
        }
    }

    void TrayIconWin32::handleTimer(UINT_PTR timerId) {
        if (timerId != kHoverTimerId) return;
        if (!messageHwnd_) return;
        if (pinnedByClick_) return;

        const DWORD now = GetTickCount();
        // 读取鼠标位置（用于判断是否仍停留在弹窗/托盘图标附近）
        POINT pt{};
        GetCursorPos(&pt);

        // 关键判断：只要鼠标仍停留在上一次 tray WM_MOUSEMOVE 时的光标位置附近，
        // 就认为仍在托盘图标上（即使鼠标不动不会继续触发 WM_MOUSEMOVE）。
        // 这样可以避免“快速划过托盘图标也弹出”的闪现问题。
        const bool cursorStillNearTrayPos = hasLastTrayCursorPos_ && IsPointNear(pt, lastTrayCursorPos_, 10);
        const bool likelyStillOnIcon = hoveringIcon_ && cursorStillNearTrayPos;

        bool inPopup = false;
        if (popup_.isVisible() && popup_.hwnd()) {
            RECT popupRc{};
            if (GetWindowRect(popup_.hwnd(), &popupRc)) {
                inPopup = PointInRect(popupRc, pt);
            }
        }

        // hover 延迟，避免鼠标经过就弹出
        const DWORD hoverDelayMs = 450;

        if (likelyStillOnIcon || inPopup) {
            if (!popup_.isVisible() && likelyStillOnIcon && (now - hoverStartTick_) >= hoverDelayMs) {
                showPopupIfNeeded();
            }
            return;
        }

        // 鼠标离开托盘图标与弹窗：隐藏并停止定时器
        hoveringIcon_ = false;
        hidePopupIfNeeded();
        KillTimer(messageHwnd_, kHoverTimerId);
    }

} // namespace pomodoro



